// Code generated by protoc-gen-go.
// source: wire.proto
// DO NOT EDIT!

/*
Package main is a generated protocol buffer package.

It is generated from these files:
	wire.proto

It has these top-level messages:
	Contact
	File
	Store
	Haber
*/
package main

import proto "github.com/golang/protobuf/proto"
import fmt "fmt"
import math "math"

// Reference imports to suppress errors if they are not otherwise used.
var _ = proto.Marshal
var _ = fmt.Errorf
var _ = math.Inf

// This is a compile-time assertion to ensure that this generated file
// is compatible with the proto package it is being compiled against.
// A compilation error at this line likely means your copy of the
// proto package needs to be updated.
const _ = proto.ProtoPackageIsVersion2 // please upgrade the proto package

// Identifies which field is filled in
type Haber_Which int32

const (
	Haber_LOGIN               Haber_Which = 0
	Haber_CONTACTS            Haber_Which = 1
	Haber_PRESENCE            Haber_Which = 2
	Haber_TEXT                Haber_Which = 3
	Haber_FILE                Haber_Which = 4
	Haber_AV                  Haber_Which = 5
	Haber_STORE               Haber_Which = 6
	Haber_LOAD                Haber_Which = 7
	Haber_PAYLOAD             Haber_Which = 8
	Haber_PUBLIC_KEY          Haber_Which = 9
	Haber_PUBLIC_KEY_RESPONSE Haber_Which = 10
	Haber_HANDSHAKE           Haber_Which = 11
	Haber_ENVELOPE            Haber_Which = 12
)

var Haber_Which_name = map[int32]string{
	0:  "LOGIN",
	1:  "CONTACTS",
	2:  "PRESENCE",
	3:  "TEXT",
	4:  "FILE",
	5:  "AV",
	6:  "STORE",
	7:  "LOAD",
	8:  "PAYLOAD",
	9:  "PUBLIC_KEY",
	10: "PUBLIC_KEY_RESPONSE",
	11: "HANDSHAKE",
	12: "ENVELOPE",
}
var Haber_Which_value = map[string]int32{
	"LOGIN":               0,
	"CONTACTS":            1,
	"PRESENCE":            2,
	"TEXT":                3,
	"FILE":                4,
	"AV":                  5,
	"STORE":               6,
	"LOAD":                7,
	"PAYLOAD":             8,
	"PUBLIC_KEY":          9,
	"PUBLIC_KEY_RESPONSE": 10,
	"HANDSHAKE":           11,
	"ENVELOPE":            12,
}

func (x Haber_Which) String() string {
	return proto.EnumName(Haber_Which_name, int32(x))
}
func (Haber_Which) EnumDescriptor() ([]byte, []int) { return fileDescriptor0, []int{3, 0} }

type Contact struct {
	Id     string `protobuf:"bytes,1,opt,name=id" json:"id,omitempty"`
	Name   string `protobuf:"bytes,2,opt,name=name" json:"name,omitempty"`
	Online bool   `protobuf:"varint,3,opt,name=online" json:"online,omitempty"`
}

func (m *Contact) Reset()                    { *m = Contact{} }
func (m *Contact) String() string            { return proto.CompactTextString(m) }
func (*Contact) ProtoMessage()               {}
func (*Contact) Descriptor() ([]byte, []int) { return fileDescriptor0, []int{0} }

func (m *Contact) GetId() string {
	if m != nil {
		return m.Id
	}
	return ""
}

func (m *Contact) GetName() string {
	if m != nil {
		return m.Name
	}
	return ""
}

func (m *Contact) GetOnline() bool {
	if m != nil {
		return m.Online
	}
	return false
}

type File struct {
	Key  string `protobuf:"bytes,1,opt,name=key" json:"key,omitempty"`
	Data []byte `protobuf:"bytes,2,opt,name=data,proto3" json:"data,omitempty"`
}

func (m *File) Reset()                    { *m = File{} }
func (m *File) String() string            { return proto.CompactTextString(m) }
func (*File) ProtoMessage()               {}
func (*File) Descriptor() ([]byte, []int) { return fileDescriptor0, []int{1} }

func (m *File) GetKey() string {
	if m != nil {
		return m.Key
	}
	return ""
}

func (m *File) GetData() []byte {
	if m != nil {
		return m.Data
	}
	return nil
}

type Store struct {
	Key   []byte `protobuf:"bytes,1,opt,name=key,proto3" json:"key,omitempty"`
	Value []byte `protobuf:"bytes,2,opt,name=value,proto3" json:"value,omitempty"`
}

func (m *Store) Reset()                    { *m = Store{} }
func (m *Store) String() string            { return proto.CompactTextString(m) }
func (*Store) ProtoMessage()               {}
func (*Store) Descriptor() ([]byte, []int) { return fileDescriptor0, []int{2} }

func (m *Store) GetKey() []byte {
	if m != nil {
		return m.Key
	}
	return nil
}

func (m *Store) GetValue() []byte {
	if m != nil {
		return m.Value
	}
	return nil
}

type Haber struct {
	Version   uint32      `protobuf:"varint,1,opt,name=version" json:"version,omitempty"`
	SessionId string      `protobuf:"bytes,2,opt,name=sessionId" json:"sessionId,omitempty"`
	From      string      `protobuf:"bytes,3,opt,name=from" json:"from,omitempty"`
	To        string      `protobuf:"bytes,4,opt,name=to" json:"to,omitempty"`
	Which     Haber_Which `protobuf:"varint,5,opt,name=which,enum=Haber_Which" json:"which,omitempty"`
	// One of the following will be filled in
	Login    string     `protobuf:"bytes,101,opt,name=login" json:"login,omitempty"`
	Contacts []*Contact `protobuf:"bytes,102,rep,name=contacts" json:"contacts,omitempty"`
	File     *File      `protobuf:"bytes,103,opt,name=file" json:"file,omitempty"`
	Store    *Store     `protobuf:"bytes,104,opt,name=store" json:"store,omitempty"`
	Raw      [][]byte   `protobuf:"bytes,105,rep,name=raw,proto3" json:"raw,omitempty"`
	Payload  []byte     `protobuf:"bytes,106,opt,name=payload,proto3" json:"payload,omitempty"`
}

func (m *Haber) Reset()                    { *m = Haber{} }
func (m *Haber) String() string            { return proto.CompactTextString(m) }
func (*Haber) ProtoMessage()               {}
func (*Haber) Descriptor() ([]byte, []int) { return fileDescriptor0, []int{3} }

func (m *Haber) GetVersion() uint32 {
	if m != nil {
		return m.Version
	}
	return 0
}

func (m *Haber) GetSessionId() string {
	if m != nil {
		return m.SessionId
	}
	return ""
}

func (m *Haber) GetFrom() string {
	if m != nil {
		return m.From
	}
	return ""
}

func (m *Haber) GetTo() string {
	if m != nil {
		return m.To
	}
	return ""
}

func (m *Haber) GetWhich() Haber_Which {
	if m != nil {
		return m.Which
	}
	return Haber_LOGIN
}

func (m *Haber) GetLogin() string {
	if m != nil {
		return m.Login
	}
	return ""
}

func (m *Haber) GetContacts() []*Contact {
	if m != nil {
		return m.Contacts
	}
	return nil
}

func (m *Haber) GetFile() *File {
	if m != nil {
		return m.File
	}
	return nil
}

func (m *Haber) GetStore() *Store {
	if m != nil {
		return m.Store
	}
	return nil
}

func (m *Haber) GetRaw() [][]byte {
	if m != nil {
		return m.Raw
	}
	return nil
}

func (m *Haber) GetPayload() []byte {
	if m != nil {
		return m.Payload
	}
	return nil
}

func init() {
	proto.RegisterType((*Contact)(nil), "Contact")
	proto.RegisterType((*File)(nil), "File")
	proto.RegisterType((*Store)(nil), "Store")
	proto.RegisterType((*Haber)(nil), "Haber")
	proto.RegisterEnum("Haber_Which", Haber_Which_name, Haber_Which_value)
}

func init() { proto.RegisterFile("wire.proto", fileDescriptor0) }

var fileDescriptor0 = []byte{
	// 492 bytes of a gzipped FileDescriptorProto
	0x1f, 0x8b, 0x08, 0x00, 0x00, 0x09, 0x6e, 0x88, 0x02, 0xff, 0x54, 0x92, 0xd1, 0x6e, 0xd3, 0x30,
	0x18, 0x85, 0x49, 0x93, 0xb4, 0xc9, 0xdf, 0xae, 0xb2, 0x0c, 0x02, 0x23, 0x4d, 0x22, 0x8a, 0x90,
	0xe8, 0x05, 0x0a, 0x52, 0x79, 0x82, 0xac, 0xf3, 0x68, 0xb5, 0x2a, 0xa9, 0x9c, 0x32, 0x18, 0x37,
	0x95, 0xdb, 0xb8, 0xad, 0x21, 0x8d, 0xa7, 0x34, 0x5b, 0xb5, 0xd7, 0xe2, 0x7d, 0x78, 0x17, 0x64,
	0x27, 0x63, 0xe2, 0xee, 0x9c, 0xf3, 0xdb, 0x7f, 0x8e, 0x3f, 0x05, 0xe0, 0x24, 0x2b, 0x11, 0xdd,
	0x55, 0xaa, 0x56, 0x21, 0x85, 0xde, 0x44, 0x95, 0x35, 0xdf, 0xd4, 0x78, 0x08, 0x1d, 0x99, 0x13,
	0x2b, 0xb0, 0x46, 0x3e, 0xeb, 0xc8, 0x1c, 0x63, 0x70, 0x4a, 0x7e, 0x10, 0xa4, 0x63, 0x12, 0xa3,
	0xf1, 0x6b, 0xe8, 0xaa, 0xb2, 0x90, 0xa5, 0x20, 0x76, 0x60, 0x8d, 0x3c, 0xd6, 0xba, 0xf0, 0x23,
	0x38, 0x57, 0xb2, 0x10, 0x18, 0x81, 0xfd, 0x4b, 0x3c, 0xb6, 0x4b, 0xb4, 0xd4, 0x5b, 0x72, 0x5e,
	0x73, 0xb3, 0x65, 0xc0, 0x8c, 0x0e, 0x3f, 0x81, 0x9b, 0xd5, 0xaa, 0xfa, 0xef, 0xf8, 0xa0, 0x39,
	0xfe, 0x0a, 0xdc, 0x07, 0x5e, 0xdc, 0x8b, 0xf6, 0x7c, 0x63, 0xc2, 0x3f, 0x36, 0xb8, 0x53, 0xbe,
	0x16, 0x15, 0x26, 0xd0, 0x7b, 0x10, 0xd5, 0x51, 0xaa, 0xd2, 0xdc, 0x3a, 0x63, 0x4f, 0x16, 0x9f,
	0x83, 0x7f, 0x14, 0x47, 0x2d, 0x67, 0x79, 0xdb, 0xf9, 0x39, 0xd0, 0x35, 0xb6, 0x95, 0x3a, 0x98,
	0xda, 0x3e, 0x33, 0x5a, 0x3f, 0xb8, 0x56, 0xc4, 0x69, 0x1e, 0x5c, 0x2b, 0x1c, 0x82, 0x7b, 0xda,
	0xcb, 0xcd, 0x9e, 0xb8, 0x81, 0x35, 0x1a, 0x8e, 0x07, 0x91, 0xf9, 0x64, 0xf4, 0x4d, 0x67, 0xac,
	0x19, 0xe9, 0x7e, 0x85, 0xda, 0xc9, 0x92, 0x08, 0x73, 0xad, 0x31, 0xf8, 0x3d, 0x78, 0x9b, 0x86,
	0xe2, 0x91, 0x6c, 0x03, 0x7b, 0xd4, 0x1f, 0x7b, 0x51, 0x8b, 0x95, 0xfd, 0x9b, 0xe0, 0xb7, 0xe0,
	0x6c, 0x65, 0x21, 0xc8, 0x2e, 0xb0, 0x46, 0xfd, 0xb1, 0x1b, 0x69, 0x62, 0xcc, 0x44, 0xf8, 0x1c,
	0xdc, 0xa3, 0x26, 0x42, 0xf6, 0x66, 0xd6, 0x8d, 0x0c, 0x1f, 0xd6, 0x84, 0x1a, 0x53, 0xc5, 0x4f,
	0x44, 0x06, 0xb6, 0xc6, 0x54, 0xf1, 0x93, 0xc6, 0x70, 0xc7, 0x1f, 0x0b, 0xc5, 0x73, 0xf2, 0xd3,
	0x80, 0x7a, 0xb2, 0xe1, 0x6f, 0x0b, 0x5c, 0xd3, 0x18, 0xfb, 0xe0, 0xce, 0xd3, 0x2f, 0xb3, 0x04,
	0xbd, 0xc0, 0x03, 0xf0, 0x26, 0x69, 0xb2, 0x8c, 0x27, 0xcb, 0x0c, 0x59, 0xda, 0x2d, 0x18, 0xcd,
	0x68, 0x32, 0xa1, 0xa8, 0x83, 0x3d, 0x70, 0x96, 0xf4, 0xfb, 0x12, 0xd9, 0x5a, 0x5d, 0xcd, 0xe6,
	0x14, 0x39, 0xb8, 0x0b, 0x9d, 0xf8, 0x06, 0xb9, 0x7a, 0x45, 0xb6, 0x4c, 0x19, 0x45, 0x5d, 0x3d,
	0x9c, 0xa7, 0xf1, 0x25, 0xea, 0xe1, 0x3e, 0xf4, 0x16, 0xf1, 0xad, 0x31, 0x1e, 0x1e, 0x02, 0x2c,
	0xbe, 0x5e, 0xcc, 0x67, 0x93, 0xd5, 0x35, 0xbd, 0x45, 0x3e, 0x7e, 0x03, 0x2f, 0x9f, 0xfd, 0x8a,
	0xd1, 0x6c, 0x91, 0x26, 0x19, 0x45, 0x80, 0xcf, 0xc0, 0x9f, 0xc6, 0xc9, 0x65, 0x36, 0x8d, 0xaf,
	0x29, 0xea, 0xeb, 0x0e, 0x34, 0xb9, 0xa1, 0xf3, 0x74, 0x41, 0xd1, 0xe0, 0xe2, 0x03, 0xbc, 0xab,
	0x44, 0x1e, 0xd5, 0xa2, 0x88, 0x36, 0x7b, 0x5e, 0x47, 0x3b, 0x51, 0x8a, 0x8a, 0xd7, 0x22, 0x5f,
	0x99, 0xbf, 0x74, 0x7d, 0xbf, 0xfd, 0xe1, 0x1c, 0xb8, 0x2c, 0xd7, 0x5d, 0xe3, 0x3f, 0xff, 0x0d,
	0x00, 0x00, 0xff, 0xff, 0x9a, 0x30, 0x5a, 0x9e, 0xc3, 0x02, 0x00, 0x00,
}
