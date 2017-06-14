package main

import (
  "github.com/gorilla/websocket"
  "fmt"
  "net"
  "net/http"
  "github.com/boltdb/bolt"
  "github.com/golang/protobuf/proto"
  "log"
)

//global variable for handling all chat traffic
var crowd Crowd

// websocket

var upgrader = websocket.Upgrader {
  ReadBufferSize:  1024,
  WriteBufferSize: 1024,
  CheckOrigin:     func(r *http.Request) bool { return true }, //not checking origin
}

func connected(w http.ResponseWriter, r *http.Request) {
  fmt.Println("\nNew connection\n")
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
        crowd.updatePresence(sessionId, false)
        return
      }

      haber := &Haber{}
      err = proto.Unmarshal(data, haber)
      if err != nil {
        fmt.Println("unmarshaling error: ", err)
        return
      }

      if crowd.messageArrived(conn, haber, sessionId) {
        return // received error, stop loop
      }
    }
  }()
}

// Printing out the various ways the server can be reached by the clients
func printClientConnInfo() {
  addrs, err := net.InterfaceAddrs()
  if err != nil {
    log.Fatal(err)
    return
  }

  fmt.Println("clients can connect at the following addresses:")
  for _, a := range addrs {
    if a.String() != "0.0.0.0" {
      fmt.Println("http://" + a.String() + ":8000/\n")
    }
  }
}

// Database

func openDb() (*bolt.DB) {
  db, err := bolt.Open("crowd.db", 0600, nil)
  if err != nil {
    log.Fatal(err)
  }
  return db
}

// main

func main() {
  db := openDb()
  printClientConnInfo()
  http.HandleFunc("/ws", connected)
  crowd.Init(db)
  http.ListenAndServe(":8000", nil)
  defer db.Close()
}