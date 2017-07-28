package main

import (
  "github.com/gorilla/websocket"
  "fmt"
  "math/rand"
  "sync"
  "github.com/boltdb/bolt"
)

type Crowd struct {
  clients             map[string]*Client
  presenceSubscribers map[string][]string // set of subscribers to each client
  clientsMtx          sync.Mutex
  queue               chan Haber
  db                  *bolt.DB
}

func (crowd *Crowd) Init(db *bolt.DB) {
  crowd.queue = make(chan Haber, 5)
  crowd.clients = make(map[string]*Client)
  crowd.presenceSubscribers = make(map[string][]string)
  crowd.db = db

  // loop to send messages from queue
  go func() {
    for {
      message := <-crowd.queue
      to := message.GetTo()
      if to == "" {
        fmt.Println("Send " + message.GetWhich().String() + " to whom?")
        return
      }

      client, ok := crowd.clients[to]
      if ok == false {
        fmt.Println("Can't find " + to)
        return
      }

      which := message.Which
      if which != Haber_CONTACTS { // don't forward sessionId
        message.SessionId = ""
      }
      fmt.Printf("Send %s from %s to %s\n", message.GetWhich().String(), message.From, message.To);
      client.Send(&message)

      //if (which == Haber_TEXT || which == Haber_FILE) && (message.To != message.From) {
      //  message.To = message.From
      //  fmt.Println("\t also send " + message.GetWhich().String() + " from " + message.From + " to " + message.To)
      //  crowd.queue <- message
      //}
    }
  }()
}

func (crowd *Crowd) messageArrived(conn *websocket.Conn, haber *Haber, sessionId string) bool {
  if haber.GetWhich() == Haber_LOGIN {
    crowd.receivedLogin(conn, haber.GetLogin())
    return false
  }
  sessionId = haber.GetSessionId()
  if sessionId != "" {
    fmt.Println("\nsessionId is " + sessionId)
    crowd.updatePresence(sessionId, true)
  }

  client, ok := crowd.clients[sessionId]
  fmt.Printf("\nok is %t\n", ok)
  if !ok {
    if client == nil && sessionId != "" {
      fmt.Println("no client for " + sessionId)
      return true
    } else {
      fmt.Println("sessionId is empty, which=" + haber.GetWhich().String())
    }
  }

  switch haber.GetWhich() {
  case Haber_CONTACTS:
    client.receivedContacts(haber)
  case Haber_STORE:
    client.receivedStore(haber)
  case Haber_LOAD:
    client.receivedLoad(haber)
  case Haber_PUBLIC_KEY:
    fallthrough
  case Haber_PUBLIC_KEY_RESPONSE:
    fallthrough
  case Haber_HANDSHAKE:
    fallthrough
  case Haber_PAYLOAD:
    if client == nil {
      fmt.Printf("client is nil %d\n", len(crowd.clients))
    }
    if haber == nil {
      fmt.Println("haber is nil")
    }
    forward(client, haber)
  default:
    fmt.Println("No handler for " + haber.GetWhich().String())
  }
  return false
}

func (crowd *Crowd) receivedLogin(conn *websocket.Conn, id string) {
  fmt.Println("receivedLogin: " + id)
  defer crowd.clientsMtx.Unlock()
  crowd.clientsMtx.Lock()

  sessionId := createSessionId()

  var client *Client
  if c, ok := crowd.clients[id]; ok {
    client = c
  } else {
    client = &Client{
      id:       id,
      sessions: make(map[string]*websocket.Conn),
      online:   false,
    }
  }
  client.sessions[sessionId] = conn
  crowd.clients[id] = client
  fmt.Printf("new client id=%s, session=%s, len=%d\n", client.id, sessionId, len(client.sessions))
  client.Load(crowd.db)
  crowd.clients[sessionId] = client
  client.sendContacts(sessionId)
  crowd.updatePresence(sessionId, true)
}

// todo: need a real GUID generator
func createSessionId() string{
  alphanum := "0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz"
  var bytes = make([]byte, 10)
  rand.Read(bytes)
  for i, b := range bytes {
    bytes[i] = alphanum[b%byte(len(alphanum))]
  }
  return string(bytes)
}

func (crowd *Crowd) updatePresence(sessionId string, online bool) {
  client, ok := crowd.clients[sessionId]
  if !ok {
    fmt.Println("\t can't find " + sessionId)
    return
  }

  fmt.Printf("put %s / %s, size is %d\n", client.id, sessionId, len(crowd.clients))
  crowd.clients[sessionId] = client
  if online == client.online {
    return
  } else {
    fmt.Printf("updatePresence sessionId=%s online=%t\n`", sessionId, online)
  }
  client.online = online

  // inform subscribers
  from := client.id
  contact := &Contact{
    Id: from,
    Online: online,
  }

  for _,subscriber := range crowd.presenceSubscribers[from] {
    fmt.Println("\t subscriber= " + subscriber)
    update := &Haber {
      Which: Haber_PRESENCE,
      Contacts: []*Contact{contact},
      To: subscriber,
    }
    fmt.Printf("\t contacts length = %d\n", len(update.GetContacts()))
    crowd.queue <- *update
  }
  client.subscribeToContacts()
}