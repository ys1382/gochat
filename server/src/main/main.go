package main

import (
  "github.com/gorilla/websocket"
  "fmt"
  "math/rand"
  "net"
  "net/http"
  "sync"
  "github.com/boltdb/bolt"
  "github.com/golang/protobuf/proto"
  "log"
)

// ChatRoom

type ChatRoom struct {
  clients             map[string]*Client
  namedClients        map[string]*Client
  presenceSubscribers map[string][]string // set of subscribers to each client
  clientsMtx          sync.Mutex
  queue               chan Haber
  db                  *bolt.DB
}

func (cr *ChatRoom) Init(db *bolt.DB) {
  cr.queue = make(chan Haber, 5)
  cr.clients = make(map[string]*Client)
  cr.namedClients = make(map[string]*Client)
  cr.presenceSubscribers = make(map[string][]string)
  cr.db = db

  go func() {
    for {
      message := <-cr.queue
      to := message.GetTo()
      if to == "" {
        fmt.Println("Send " + message.GetWhich().String() + " to whom?")
        return
      }

      client, ok := cr.namedClients[to]
      if ok == false {
        fmt.Println("Can't find " + to)
      } else {
        which := message.Which
        if which != Haber_CONTACTS { // don't forward sessionId
          message.SessionId = ""
        }
        fmt.Println("Send " + message.GetWhich().String() + " from " + message.From + " to " + message.To)
        client.Send(&message)

        if (which == Haber_TEXT || which == Haber_FILE) && (message.To != message.From) {
          message.To = message.From
          fmt.Println("\t also send " + message.GetWhich().String() + " from " + message.From + " to " + message.To)
          cr.queue <- message
        }
      }
    }
  }()
}

// Client

type Client struct {
  name       string
  contacts   []*Contact
  sessions   map[string]*websocket.Conn
  online     bool
}

func (cl *Client) Save(db *bolt.DB, haber *Haber) {
  db.Update(func(tx *bolt.Tx) error {
    b, err := tx.CreateBucketIfNotExists([]byte(cl.name))
    if err != nil {
      fmt.Println("Error opening bucket:", err)
    }
    encoded, err := proto.Marshal(haber)
    if err != nil {
      fmt.Println("Error marshalling:", err)
    }
    return b.Put([]byte("contacts"), encoded)
  })
}

func (cl *Client) Load(db *bolt.DB) {
  db.View(func(tx *bolt.Tx) error {
    b := tx.Bucket([]byte(cl.name))
    if b != nil {
      data := b.Get([]byte("contacts"))
      if data == nil {
        fmt.Println("contacts are nil for " + cl.name)
      } else {
        var haber Haber
        err := proto.Unmarshal(data, &haber)
        if err != nil {
          fmt.Println("Error unmarshalling:", err)
        } else {
          cl.contacts = haber.GetContacts()
        }
      }
    }
    return nil
  })
}

func (cl *Client) isOnline() (bool) {
  return len(cl.sessions) > 0
}

func (cl *Client) Send(haber *Haber) {
  cl.SendToSession(haber, "")
}

func (cl *Client) SendToSession(haber *Haber, sessionId string) {
  data, err := proto.Marshal(haber)
  if err != nil || data == nil {
    fmt.Println("Error marshalling:", err)
  }  else if cl == nil {
    fmt.Println("Send - cl is nil")
  } else {
    for id,conn := range cl.sessions {
      if sessionId == "" || sessionId == id {
        conn.WriteMessage(websocket.BinaryMessage, data)
      }
    }
  }
}

//global variable for handling all chat traffic

var chat ChatRoom

// websocket

var upgrader = websocket.Upgrader {
  ReadBufferSize:  1024,
  WriteBufferSize: 1024,
  CheckOrigin:     func(r *http.Request) bool { return true }, //not checking origin
}

func wsHandler(w http.ResponseWriter, r *http.Request) {
  fmt.Println("New connection")
  conn, err := upgrader.Upgrade(w, r, nil)
  if err != nil {
    fmt.Println("Error upgrading to websocket:", err)
    return
  }

  sessionId := ""

  go func() {

    for {
      _, data, err := conn.ReadMessage()
      if err != nil {
        fmt.Println("\nConnection closed for session " + sessionId)
        updatePresence(sessionId, false)
        return
      }

      haber := &Haber{}
      err = proto.Unmarshal(data, haber)
      if err != nil {
        fmt.Println("unmarshaling error: ", err)
        return
      }

      if haber.GetWhich() == Haber_LOGIN {
        receivedUsername(conn, haber.GetLogin().GetUsername())
        continue
      }
      sessionId = haber.GetSessionId()
      if sessionId != "" {
        fmt.Println("\nsessionId is " + sessionId)
        updatePresence(sessionId, true)
      }
      client, ok := chat.clients[sessionId]
      if !ok {
        fmt.Println("no client for " + sessionId)
        return
      }

      switch haber.GetWhich() {
      case Haber_CONTACTS:
        receivedContacts(client, haber)
      case Haber_STORE:
        receivedStore(client, haber)
      case Haber_LOAD:
        receivedLoad(client, haber)
      case Haber_TEXT:
        fallthrough
      case Haber_FILE:
          forward(client, haber)
      }
    }
  }()
}

func receivedLoad(client *Client, haber *Haber) {
  chat.db.View(func(tx *bolt.Tx) error {
    b := tx.Bucket([]byte(client.name))
    if b == nil {
      fmt.Println("no bucket for " + client.name)
      return nil
    }
    key := haber.Load.GetKey()
    data := b.Get(key)
    if data == nil {
      fmt.Println("data is nil for " + string(key[:]))
      return nil
    }
    store := &Store{
      Key:   key,
      Value: data,
    }
    update := &Haber{
      Which: Haber_STORE,
      Store: store,
      To:    client.name,
    }
    chat.queue <- *update
    return nil
  })
}

func receivedStore(client *Client, haber *Haber) {
  chat.db.Update(func(tx *bolt.Tx) error {
    b, err := tx.CreateBucketIfNotExists([]byte(client.name))
    if err != nil {
      fmt.Println("Error opening bucket:", err)
    }
    return b.Put(haber.Store.Key, haber.GetStore().GetValue())
  })
}

func updatePresence(sessionId string, online bool) {
  client, ok := chat.clients[sessionId]
  if !ok {
    fmt.Println("\t can't find " + sessionId)
  }

  if online == client.online {
    fmt.Printf("updatePresence: %s is already %t\n", client.name, client.online)
    return
  } else {
    fmt.Println("updatePresence sessionId=" + sessionId)
  }
  client.online = online
  chat.clients[sessionId] = client

  // inform subscribers
  from := client.name
  contact := &Contact{
    Name: from,
    Online: online,
  }
  for _,subscriber := range chat.presenceSubscribers[from] {
    fmt.Println("\t subscriber name =" + subscriber)
    update := &Haber {
      Which: Haber_PRESENCE,
      Contacts: []*Contact{contact},
      To: subscriber,
    }
    fmt.Printf("\t contacts length = %d\n", len(update.GetContacts()))
    chat.queue <- *update
  }
  client.subscribeToContacts()
}

func (cl *Client)subscribeToContacts() {
  from := cl.name
  fmt.Println("subscribeToContacts from " + from)
  for _,contact := range cl.contacts {
    contactName := contact.GetName()
    fmt.Println("\t contactName=" + contactName)
    if cl.online {
      if _,ok := chat.presenceSubscribers[contactName]; !ok {
        chat.presenceSubscribers[contactName] = []string{from}
      } else {
        chat.presenceSubscribers[contactName] = append(chat.presenceSubscribers[contactName], from)
      }
    } else { // offline
      chat.presenceSubscribers[contactName] = remove(chat.presenceSubscribers[contactName], from)
      if len(chat.presenceSubscribers[contactName]) == 0 {
        delete(chat.presenceSubscribers, contactName)
      }
    }
  }
}

func remove(s []string, r string) []string {
  for i, v := range s {
    if v == r {
      return append(s[:i], s[i+1:]...)
    }
  }
  return s
}

func receivedUsername(conn *websocket.Conn, username string) {
  fmt.Println("\nreceivedUsername: " + username)
  defer chat.clientsMtx.Unlock()
  chat.clientsMtx.Lock()

  sessionId := createSessionId()

  var client *Client
  if c, ok := chat.namedClients[username]; ok {
    client = c
  } else {
    client = &Client{
      name:     username,
      sessions: make(map[string]*websocket.Conn),
      online:   true,
    }
  }
  client.sessions[sessionId] = conn
  chat.namedClients[username] = client
  fmt.Println("new client name=" + client.name + " session=" + sessionId)
  client.Load(chat.db)
  chat.clients[sessionId] = client
  sendContacts(client, sessionId)
  updatePresence(sessionId, true)
}

func sendContacts(client *Client, sessionId string) {
  for _,contact := range client.contacts {
    _,ok := chat.namedClients[contact.Name]
    contact.Online = ok
  }

  buds := &Haber {
    Which: Haber_CONTACTS,
    SessionId: sessionId,
    Contacts: client.contacts,
    To: client.name,
  }
  chat.queue <- *buds
}

func forward(client *Client, haber *Haber) {
  haber.From = client.name
  chat.queue <- *haber // forward to all devices with source's and destination's names
}

func receivedContacts(client *Client, haber *Haber) {
  fmt.Println("receivedContacts for " + client.name)
  client.contacts = haber.GetContacts()
  client.subscribeToContacts()
  client.Save(chat.db, haber)

  for _,contact := range haber.Contacts {
    if c, ok := chat.namedClients[contact.Name]; ok {
      contact.Online = c.online
    }
  }
  haber.To = client.name
  forward(client, haber)
}

func createSessionId() string{
  alphanum := "0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz"
  var bytes = make([]byte, 10)
  rand.Read(bytes)
  for i, b := range bytes {
    bytes[i] = alphanum[b%byte(len(alphanum))]
  }
  return string(bytes)
}

// Printing out the various ways the server can be reached by the clients
func printClientConnInfo() {
  addrs, err := net.InterfaceAddrs()
  if err != nil {
    log.Fatal(err)
    return
  }

  fmt.Println("Chat clients can connect at the following addresses:")
  for _, a := range addrs {
    if a.String() != "0.0.0.0" {
      fmt.Println("http://" + a.String() + ":8000/\n")
    }
  }
}

// Database

func openDb() (*bolt.DB) {
  db, err := bolt.Open("chat.db", 0600, nil)
  if err != nil {
    log.Fatal(err)
  }
  return db
}

// main

func main() {
  db := openDb()
  printClientConnInfo()
  http.HandleFunc("/ws", wsHandler)
  chat.Init(db)
  http.ListenAndServe(":8000", nil)
  defer db.Close()
}
