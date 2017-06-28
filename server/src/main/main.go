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

      client := getNamedClient(to)

      if client == nil {
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

func getClient(sessionId string) (*Client) {
  var result *Client

  chat.clientsMtx.Lock()
  result = chat.clients[sessionId]
  chat.clientsMtx.Unlock()

  return result
}

func setClient(sessionId string, client *Client) {
  chat.clientsMtx.Lock()
  chat.clients[sessionId] = client
  chat.clientsMtx.Unlock()
}

func getNamedClient(name string) (*Client) {
  var result *Client

  chat.clientsMtx.Lock()
  result = chat.namedClients[name]
  chat.clientsMtx.Unlock()

  return result
}

func setNamedClient(name string, client *Client) {
  chat.clientsMtx.Lock()
  chat.namedClients[name] = client
  chat.clientsMtx.Unlock()
}

func getPresenceSubscribers(name string) ([]string) {
  var result []string

  chat.clientsMtx.Lock()
  result = chat.presenceSubscribers[name]
  chat.clientsMtx.Unlock()

  return result
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
        fmt.Println("Error ", err)
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

      sessionId = haber.GetSessionId()
      if sessionId != "" {
        fmt.Println("\nsessionId is " + sessionId)
        updatePresence(sessionId, true)
      }

      switch haber.GetWhich() {
      case Haber_LOGIN:
        sessionId = receivedUsername(conn, haber.GetLogin().GetUsername())
      case Haber_CONTACTS:
        receivedContacts(sessionId, haber)
      case Haber_AV:
        fallthrough
      case Haber_AudioSession:
        fallthrough
      case Haber_VideoSession:
        fallthrough
      case Haber_TEXT:
        fallthrough
      case Haber_CALL_PROPOSAL:
        fallthrough
      case Haber_CALL_CANCEL:
        fallthrough
      case Haber_CALL_ACCEPT:
        fallthrough
      case Haber_CALL_DECLINE:
        fallthrough
      case Haber_CALL_START_OUTGOING:
        fallthrough
      case Haber_CALL_START_INCOMING:
        fallthrough
      case Haber_CALL_STOP:
        fallthrough
      case Haber_FILE:
        if getClient(sessionId) != nil {
          forward(sessionId, haber)
        }
      }
    }
  }()
}

func updatePresence(sessionId string, online bool) {
  client := getClient(sessionId)

  if client != nil {
    if online == client.online {
      fmt.Printf("updatePresence: %s is already %t\n", client.name, client.online)
      return
    }
    fmt.Println("updatePresence sessionId=" + sessionId)
    client.online = online
    setClient(sessionId, client)
    // inform subscribers
    from := client.name
    fmt.Println("\t from=" + from)
    contact := &Contact{
      Name: from,
      Online: online,
    }
    for _,subscriber := range getPresenceSubscribers(from) {
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
  } else {
    fmt.Println("\t can't find client")
  }
}

func (cl *Client)subscribeToContacts() {
  from := cl.name
  fmt.Println("subscribeToContacts from=" + from)
  chat.clientsMtx.Lock()
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
  chat.clientsMtx.Unlock()
}

func remove(s []string, r string) []string {
  for i, v := range s {
    if v == r {
      return append(s[:i], s[i+1:]...)
    }
  }
  return s
}

func receivedUsername(conn *websocket.Conn, username string) string {
  fmt.Println("\nreceivedUsername: " + username)

  sessionId := createSessionId()

  client := getNamedClient(username)
  if client == nil {
    client = &Client{
      name:     username,
      sessions: make(map[string]*websocket.Conn),
      online: false,
    }
    setNamedClient(username, client)
    fmt.Println("create client for ", username)
  }
  client.sessions[sessionId] = conn
  fmt.Println("new client name=" + client.name + " session=" + sessionId)
  client.Load(chat.db)
  fmt.Println("receivedUsername: load db")
  setClient(sessionId, client)
  fmt.Println("receivedUsername: client setted")
  sendContacts(client, sessionId)
  fmt.Println("receivedUsername: contacts sent")
  updatePresence(sessionId, true)
  fmt.Println("receivedUsername: presence updated")

  return sessionId
}

func sendContacts(client *Client, sessionId string) {
  for _,contact := range client.contacts {
    contact.Online = getNamedClient(contact.Name) != nil
  }

  buds := &Haber {
    Which: Haber_CONTACTS,
    SessionId: sessionId,
    Contacts: client.contacts,
    To: client.name,
  }
  chat.queue <- *buds
}

func forward(sessionId string, haber *Haber) {
  sourceClient := getClient(sessionId)
  haber.From = sourceClient.name
  chat.queue <- *haber  // forward to all devices with source's and destination's names
}

func receivedContacts(sessionId string, haber *Haber) {
  fmt.Println("receivedContacts for session " + sessionId)
  client := getClient(sessionId)
  client.contacts = haber.GetContacts()
  client.subscribeToContacts()
  client.Save(chat.db, haber)
  //forward(sessionId, haber) // after this call server stops responding
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
