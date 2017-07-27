package main

import (
  "github.com/gorilla/websocket"
  "fmt"
  "github.com/boltdb/bolt"
  "github.com/golang/protobuf/proto"
)

type Client struct {
  id         string
  contacts   []*Contact
  sessions   map[string]*websocket.Conn
  online     bool
  crowd       *Crowd
}

func (client *Client) Save(db *bolt.DB, haber *Haber) {
  db.Update(func(tx *bolt.Tx) error {
    b, err := tx.CreateBucketIfNotExists([]byte(client.id))
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

func (client *Client) Load(db *bolt.DB) {
  db.View(func(tx *bolt.Tx) error {
    b := tx.Bucket([]byte(client.id))
    if b != nil {
      data := b.Get([]byte("contacts"))
      if data == nil {
        fmt.Println("contacts are nil for " + client.id)
      } else {
        var haber Haber
        err := proto.Unmarshal(data, &haber)
        if err != nil {
          fmt.Println("Error unmarshalling:", err)
        } else {
          client.contacts = haber.GetContacts()
        }
      }
    }
    return nil
  })
}

func (client *Client) isOnline() (bool) {
  return len(client.sessions) > 0
}

func (client *Client) Send(haber *Haber) {
  fmt.Println("Client.Send " + haber.Which.String())
  data, err := proto.Marshal(haber)
  if err != nil || data == nil {
    fmt.Println("Error marshalling:", err)
  }  else if client == nil {
    fmt.Println("Send - cl is nil")
  } else {
    //fmt.Printf("\t there are %d connections\n", len(client.sessions))
    for _,conn := range client.sessions {
      conn.WriteMessage(websocket.BinaryMessage, data)
    }
  }
}

func (client *Client) receivedLoad(haber *Haber) {
  crowd.db.View(func(tx *bolt.Tx) error {
    b := tx.Bucket([]byte(client.id))
    if b == nil {
      fmt.Println("no bucket for " + client.id)
      return nil
    }
    key := haber.GetPayload()
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
      To:    client.id,
    }
    crowd.queue <- *update
    return nil
  })
}

func (client *Client) receivedStore(haber *Haber) {
  crowd.db.Update(func(tx *bolt.Tx) error {
    b, err := tx.CreateBucketIfNotExists([]byte(client.id))
    if err != nil {
      fmt.Println("Error opening bucket:", err)
    }
    return b.Put(haber.Store.Key, haber.GetStore().GetValue())
  })
}

func (client *Client) subscribeToContacts() {
  from := client.id
  fmt.Println("subscribeToContacts from " + from)
  for _,contact := range client.contacts {
    contactId := contact.GetId()
    fmt.Println("\t contactId=" + contactId)
    if client.online {
      if _,ok := crowd.presenceSubscribers[contactId]; !ok {
        crowd.presenceSubscribers[contactId] = []string{from}
      } else {
        crowd.presenceSubscribers[contactId] = append(crowd.presenceSubscribers[contactId], from)
      }
    } else { // offline
      crowd.presenceSubscribers[contactId] = remove(crowd.presenceSubscribers[contactId], from)
      if len(crowd.presenceSubscribers[contactId]) == 0 {
        delete(crowd.presenceSubscribers, contactId)
      }
    }
  }
}

// remove a string from a list of strings
func remove(s []string, r string) []string {
  for i, v := range s {
    if v == r {
      return append(s[:i], s[i+1:]...)
    }
  }
  return s
}

func (client *Client) sendContacts(sessionId string) {
  for _,contact := range client.contacts {
    _,ok := crowd.clients[contact.GetId()]
    contact.Online = ok
  }

  buds := &Haber {
    Which: Haber_CONTACTS,
    SessionId: sessionId,
    Contacts: client.contacts,
    To: client.id,
  }
  crowd.queue <- *buds
}

func forward(client *Client, haber *Haber) {
  haber.From = client.id
  crowd.queue <- *haber // forward to all devices with source's and destination's ids
}

func (client *Client) receivedContacts(haber *Haber) {
  fmt.Println("receivedContacts for " + client.id)
  client.contacts = haber.GetContacts()
  client.subscribeToContacts()
  client.Save(crowd.db, haber)

  for _,contact := range haber.Contacts {
    if c, ok := crowd.clients[contact.GetId()]; ok {
      contact.Online = c.online
    }
  }
  haber.To = client.id
  forward(client, haber)
}