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
import red.tel.chat.generated_protobuf.Store;
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
    private Map<String, ArrayList<Hold>> queue = new HashMap<>();

    public static Backend shared() {
        return instance;
    }

    @Override
    protected void onHandleIntent(Intent workIntent) {
        instance = this;
        network = new Network();

        EventBus.listenFor(this, EventBus.Event.CONNECTED, () -> {
            String username = Model.shared().getUsername();
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
                    Model.shared().incomingFromServer(wire);
                    break;
                case STORE:
                    onReceiveStore(wire);
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

    // tell the server to store data
    void sendStore(String key, byte[] value) {
        try {
            ByteString encrypted = ByteString.of(crypto.keyDerivationEncrypt(value));
            ByteString keyBytes = ByteString.encodeUtf8(key);
            Store store = new Store.Builder().key(keyBytes).build();
            Wire.Builder wireBuilder = new Wire.Builder().store(store).which(Wire.Which.STORE).payload(encrypted);
            buildAndSend(wireBuilder);
        } catch (Exception exception) {
            Log.e(TAG, exception.getLocalizedMessage());
        }
    }

    // request the server to send back stored data
    void sendLoad(String key) {
        ByteString payload = ByteString.encodeUtf8(key);
        Wire.Builder wireBuilder = new Wire.Builder().which(Wire.Which.LOAD).payload(payload);
        buildAndSend(wireBuilder);
    }

    // the server sent back stored data, due to a LOAD request
    private void onReceiveStore(Wire wire) throws Exception {
        byte[] value = crypto.keyDerivationDecrypt(wire.payload.toByteArray());
        Model.shared().onReceiveStore(wire.store.key.utf8(), value);
    }

    private void onPublicKey(Wire wire) throws Exception {
        crypto.setPublicKey(
                wire.payload.toByteArray(),
                wire.from,
                wire.which == Wire.Which.PUBLIC_KEY_RESPONSE);
    }

    private void authenticated(String sessionId) {
        try {
            crypto = new Crypto(Model.shared().getUsername(), Model.shared().getPassword());
        } catch (Exception exception) {
            Log.e(TAG, exception.getLocalizedMessage());
            return;
        }
        this.sessionId = sessionId;
        EventBus.announce(EventBus.Event.AUTHENTICATED);
    }

    private class Hold {
        byte[] data;
        String peerId;
        Hold(byte[] data, String peerId) {
            this.data = data;
            this.peerId = peerId;
        }
    }

    private void enqueue(byte[] data, String peerId) {
        if (!queue.containsKey(peerId)) {
            queue.put(peerId, new ArrayList<>());
        }
        Hold hold = new Hold(data, peerId);
        queue.get(peerId).add(hold);
    }

    private void send(byte[] data, String peerId) {
        if (crypto.isSessionEstablishedFor(peerId)) {
            encryptAndSend(data, peerId);
        } else {
            enqueue(data, peerId);
        }
    }

    private void encryptAndSend(byte[] data, String peerId) {
        try {
            ByteString encrypted = ByteString.of(crypto.encrypt(data, peerId));
            Wire.Builder payloadBuilder = new Wire.Builder().payload(encrypted).which(PAYLOAD).to(peerId);
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
        instance.buildAndSend(wire);
    }

    public void sendContacts(List<Contact> contacts) {
        Wire.Builder wire = new Wire.Builder().which(CONTACTS).contacts(contacts);
        instance.buildAndSend(wire);
    }

    public void sendText(String message, String peerId) {
        okio.ByteString text = okio.ByteString.encodeUtf8(message);
        byte[] data = new Voip.Builder().which(Voip.Which.TEXT).payload(text).build().encode();
        send(data, peerId);
    }

    void sendPublicKey(byte[] key, String recipient, Boolean isResponse) {
        Wire.Which which = isResponse ? PUBLIC_KEY_RESPONSE : PUBLIC_KEY;
        sendData(which, key, recipient);
    }

    private void sendData(Wire.Which which, byte[] data, String recipient) {
        okio.ByteString byteString = ByteString.of(data);
        Wire.Builder wire = new Wire.Builder().which(which).payload(byteString).to(recipient);
        instance.buildAndSend(wire);
    }

    void sendHandshake(byte[] key, String recipient) {
        sendData(HANDSHAKE, key, recipient);
    }

    void handshook(String peerId) {
        ArrayList<Hold> list = queue.get(peerId);
        if (list == null) {
            return;
        }
        for (Hold hold: list) {
            encryptAndSend(hold.data, hold.peerId);
        }
    }

    void onReceiveFromPeer(byte[] binary, String peerId) {
        try {
            Voip voip = Voip.ADAPTER.decode(binary);
            Log.d(TAG, "incoming " + voip.which + " from " + peerId);

            switch (voip.which) {
                case TEXT:
                    Model.shared().incomingFromPeer(voip, peerId);
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
