package red.tel.chat;

import android.app.IntentService;
import android.content.Intent;
import android.util.Log;

import java.util.HashMap;
import java.util.Map;
import java.util.ArrayList;
import java.util.List;

import okio.ByteString;
import red.tel.chat.generated_protobuf.Contact;
import red.tel.chat.generated_protobuf.Wire;
import red.tel.chat.generated_protobuf.Voip;

import static red.tel.chat.generated_protobuf.Wire.Which.CONTACTS;
import static red.tel.chat.generated_protobuf.Wire.Which.HANDSHAKE;
import static red.tel.chat.generated_protobuf.Wire.Which.PAYLOAD;
import static red.tel.chat.generated_protobuf.Wire.Which.LOGIN;
import static red.tel.chat.generated_protobuf.Wire.Which.PUBLIC_KEY;
import static red.tel.chat.generated_protobuf.Wire.Which.PUBLIC_KEY_RESPONSE;

// shuttles data between Network and Model
public class Backend extends IntentService {

    private static final String TAG = "Backend";
    private static Backend instance;
    public Backend() {
        super(TAG);
    }
    private Network network;
    private String sessionId;
    private Crypto crypto;


    private Map<String, ArrayList<Wire>> queue = new HashMap<>();

    public static Backend shared() {
        return instance;
    }

    @Override
    protected void onHandleIntent(Intent workIntent) {
        instance = this;
        network = new Network();

        EventBus.listenFor(this, EventBus.Event.CONNECTED, () -> {
            String username = Model.getUsername();
            if (username != null) {
                Backend.this.login(username);
            }
        });
    }

    // receive from Network
    void onReceiveFromServer(byte[] binary) {
        try {
            Wire wire = Wire.ADAPTER.decode(binary);
            Log.d(TAG, "incoming " + wire.which + " from server");

            if (sessionId == null && wire.sessionId != null) {
                authenticated(wire.sessionId);
            }

            switch (wire.which) {
                case CONTACTS:
                case PRESENCE:
                    Model.incomingFromServer(wire);
                    break;
                case STORE:
//                    onStore(wire);
                    break;
                case HANDSHAKE:
                case PAYLOAD:
                    crypto.onReceivePayload(wire.payload.toByteArray(), wire.from);
                    break;
                case PUBLIC_KEY:
                case PUBLIC_KEY_RESPONSE:
                    onPublicKey(wire);
                    break;
            }
        } catch (Exception exception) {
            Log.e(TAG, exception.getLocalizedMessage());
        }
    }

    private void onPublicKey(Wire wire) throws Exception {
        crypto.setPublicKey(
                wire.payload.toByteArray(),
                wire.from,
                wire.which == Wire.Which.PUBLIC_KEY_RESPONSE);
    }

    private void authenticated(String sessionId) {
        try {
            crypto = new Crypto(Model.getUsername(), Model.getPassword());
        } catch (Exception exception) {
            Log.e(TAG, exception.getLocalizedMessage());
            return;
        }
        this.sessionId = sessionId;
        EventBus.announce(EventBus.Event.AUTHENTICATED);
    }

    private void enqueue(Wire.Builder wireBuilder) {
        if (!queue.containsKey(wireBuilder.to)) {
            queue.put(wireBuilder.to, new ArrayList<>());
        }
        queue.get(wireBuilder.to).add(wireBuilder.build());
    }

    private Boolean dontEncrypt(Wire.Builder wireBuilder) {
        return wireBuilder.to == null ||
                wireBuilder.which == PUBLIC_KEY ||
                wireBuilder.which == PUBLIC_KEY_RESPONSE ||
                wireBuilder.which == HANDSHAKE;
    }

    private void send(Wire.Builder wireBuilder) {
        if (dontEncrypt(wireBuilder)) {
            buildAndSend(wireBuilder);
        } else if (crypto.isSessionEstablishedFor(wireBuilder.to)) {
            encryptAndSend(wireBuilder.build());
        } else {
            enqueue(wireBuilder);
        }
    }

    private void encryptAndSend(Wire wire) {
        try {
            ByteString encrypted = ByteString.of(crypto.encrypt(wire.encode(), wire.to));
            Wire.Builder payloadBuilder = new Wire.Builder().payload(encrypted).which(PAYLOAD).to(wire.to);
            buildAndSend(payloadBuilder);
        } catch (Exception exception) {
            Log.e(TAG, exception.getLocalizedMessage());
        }
    }

    private void buildAndSend(Wire.Builder wireBuilder) {
        wireBuilder.sessionId = sessionId;
        send(wireBuilder.build());
    }

    private void send(Wire wire) {
        network.send(wire.encode());
    }

    // send to Network

    public void login(String username) {
        Wire.Builder wire = new Wire.Builder().which(LOGIN).login(username);
        instance.send(wire);
    }

    public void sendContacts(List<Contact> contacts) {
        Wire.Builder wire = new Wire.Builder().which(CONTACTS).contacts(contacts);
        instance.send(wire);
    }

    public void sendText(String message, String peerId) {
        okio.ByteString text = okio.ByteString.encodeUtf8(message);
        Voip.Builder voipBulder = new Voip.Builder().which(Voip.Which.TEXT).payload(text);
        send(voipBulder, peerId);
    }

    private void send(Voip.Builder voipBulder, String peerId) {
        ByteString payload = ByteString.of(voipBulder.build().encode());
        Wire.Builder wireBuilder = new Wire.Builder().payload(payload).which(PAYLOAD).to(peerId);
        send(wireBuilder);
    }

    void sendPublicKey(byte[] key, String recipient, Boolean isResponse) {
        Wire.Which which = isResponse ? PUBLIC_KEY_RESPONSE : PUBLIC_KEY;
        sendData(which, key, recipient);
    }

    private void sendData(Wire.Which which, byte[] data, String recipient) {
        okio.ByteString byteString = ByteString.of(data);
        Wire.Builder wire = new Wire.Builder().which(which).payload(byteString).to(recipient);
        instance.send(wire);
    }

    void sendHandshake(byte[] key, String recipient) {
        sendData(HANDSHAKE, key, recipient);
    }

    void handshook(String peerId) {
        ArrayList<Wire> list = queue.get(peerId);
        if (list == null) {
            return;
        }
        for (Wire wire: list) {
            encryptAndSend(wire);
        }
    }

    void onReceiveFromPeer(byte[] binary, String peerId) {
        try {
            Voip voip = Voip.ADAPTER.decode(binary);
            Log.d(TAG, "incoming " + voip.which + " from " + peerId);

            switch (voip.which) {
                case TEXT:
                    Model.incomingFromPeer(voip);
                    break;
                default:
                    Log.e(TAG, "no handler for " + voip.which);
                    break;
            }
        } catch (Exception exception) {
            Log.e(TAG, exception.getLocalizedMessage());
        }
    }
}
