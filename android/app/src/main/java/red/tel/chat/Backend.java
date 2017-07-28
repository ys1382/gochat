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

import static red.tel.chat.generated_protobuf.Wire.Which.CONTACTS;
import static red.tel.chat.generated_protobuf.Wire.Which.HANDSHAKE;
import static red.tel.chat.generated_protobuf.Wire.Which.PAYLOAD;
import static red.tel.chat.generated_protobuf.Wire.Which.LOGIN;
import static red.tel.chat.generated_protobuf.Wire.Which.PUBLIC_KEY;
import static red.tel.chat.generated_protobuf.Wire.Which.PUBLIC_KEY_RESPONSE;
import static red.tel.chat.generated_protobuf.Wire.Which.TEXT;

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
    void onReceiveData(byte[] binary) {
        try {
            Wire haber = Haber.ADAPTER.decode(binary);
            Log.d(TAG, "incoming " + haber.which);

            if (sessionId == null && haber.sessionId != null) {
                authenticated(haber.sessionId);
            }

            switch (haber.which) {
                case TEXT:
                case CONTACTS:
                case PRESENCE:
                    Model.incoming(haber);
                    break;
                case STORE:
//                    onStore(haber);
                    break;
                case HANDSHAKE:
                case PAYLOAD:
                    crypto.onReceivePayload(haber.payload.toByteArray(), haber.from);
                    break;
                case PUBLIC_KEY:
                case PUBLIC_KEY_RESPONSE:
                    onPublicKey(haber);
                    break;
            }
        } catch (Exception exception) {
            Log.e(TAG, exception.getLocalizedMessage());
        }
    }

    private void onPublicKey(Wire haber) throws Exception {
        crypto.setPublicKey(
                haber.payload.toByteArray(),
                haber.from,
                haber.which == Wire.Which.PUBLIC_KEY_RESPONSE);
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

    private void enqueue(Wire.Builder haberBuilder) {
        if (!queue.containsKey(haberBuilder.to)) {
            queue.put(haberBuilder.to, new ArrayList<>());
        }
        queue.get(haberBuilder.to).add(haberBuilder.build());
    }

    private Boolean dontEncrypt(Wire.Builder haberBuilder) {
        return haberBuilder.to == null ||
                haberBuilder.which == PUBLIC_KEY ||
                haberBuilder.which == PUBLIC_KEY_RESPONSE ||
                haberBuilder.which == HANDSHAKE;
    }

    private void send(Wire.Builder haberBuilder) {
        if (dontEncrypt(haberBuilder)) {
            buildAndSend(haberBuilder);
        } else if (crypto.isSessionEstablishedFor(haberBuilder.to)) {
            encryptAndSend(haberBuilder.build());
        } else {
            enqueue(haberBuilder);
        }
    }

    private void encryptAndSend(Wire haber) {
        try {
            ByteString encrypted = ByteString.of(crypto.encrypt(haber.encode(), haber.to));
            Wire.Builder payloadBuilder = new Haber.Builder().payload(encrypted).which(PAYLOAD).to(haber.to);
            buildAndSend(payloadBuilder);
        } catch (Exception exception) {
            Log.e(TAG, exception.getLocalizedMessage());
        }
    }

    private void buildAndSend(Wire.Builder haberBuilder) {
        haberBuilder.sessionId = sessionId;
        send(haberBuilder.build());
    }

    private void send(Wire haber) {
        network.send(haber.encode());
    }

    // send to Network

    public void login(String username) {
        Wire.Builder haber = new Haber.Builder().which(LOGIN).login(username);
        instance.send(haber);
    }

    public void sendContacts(List<Contact> contacts) {
        Wire.Builder haber = new Haber.Builder().which(CONTACTS).contacts(contacts);
        instance.send(haber);
    }

    public void sendText(String recipient, String message) {
        okio.ByteString text = okio.ByteString.encodeUtf8(message);
        Wire.Builder haber = new Haber.Builder().which(TEXT).payload(text).to(recipient);
        instance.send(haber);
    }

    void sendPublicKey(byte[] key, String recipient, Boolean isResponse) {
        Wire.Which which = isResponse ? PUBLIC_KEY_RESPONSE : PUBLIC_KEY;
        sendData(which, key, recipient);
    }

    private void sendData(Wire.Which which, byte[] data, String recipient) {
        okio.ByteString byteString = ByteString.of(data);
        Wire.Builder haber = new Haber.Builder().which(which).payload(byteString).to(recipient);
        instance.send(haber);
    }

    void sendHandshake(byte[] key, String recipient) {
        sendData(HANDSHAKE, key, recipient);
    }

    void handshook(String peerId) {
        ArrayList<Wire> list = queue.get(peerId);
        if (list == null) {
            return;
        }
        for (Wire haber: list) {
            encryptAndSend(haber);
        }
    }
}
