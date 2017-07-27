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
import red.tel.chat.generated_protobuf.Haber;
import red.tel.chat.ui.BaseActivity;

import static red.tel.chat.generated_protobuf.Haber.Which.CONTACTS;
import static red.tel.chat.generated_protobuf.Haber.Which.HANDSHAKE;
import static red.tel.chat.generated_protobuf.Haber.Which.PAYLOAD;
import static red.tel.chat.generated_protobuf.Haber.Which.LOGIN;
import static red.tel.chat.generated_protobuf.Haber.Which.PUBLIC_KEY;
import static red.tel.chat.generated_protobuf.Haber.Which.PUBLIC_KEY_RESPONSE;
import static red.tel.chat.generated_protobuf.Haber.Which.TEXT;

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


    private Map<String, ArrayList<Haber>> queue = new HashMap<>();

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
            Haber haber = Haber.ADAPTER.decode(binary);
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

    private void onPublicKey(Haber haber) throws Exception {
        crypto.setPublicKey(
                haber.payload.toByteArray(),
                haber.from,
                haber.which == Haber.Which.PUBLIC_KEY_RESPONSE);
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

    private void send(Haber.Builder haberBuilder) {
        Log.d(TAG, "send " + haberBuilder.which.getValue());
        haberBuilder.sessionId = sessionId;
        Haber haber = haberBuilder.build();

        if (dontEncrypt(haber) ||
                crypto.isSessionEstablishedFor(haberBuilder.to)) {
            send(haber);
        } else {
            enqueue(haber);
        }
    }
    
    private void enqueue(Haber haber) {
        if (!queue.containsKey(haber.to)) {
            queue.put(haber.to, new ArrayList<>());
        }
        queue.get(haber.to).add(haber);
    }

    private Boolean dontEncrypt(Haber haber) {
        return
                haber.to == null ||
                haber.which == PUBLIC_KEY ||
                haber.which == PUBLIC_KEY_RESPONSE ||
                haber.which == HANDSHAKE;
    }

    private void send(Haber haber) {
        byte[] bytes = Haber.ADAPTER.encode(haber);
        if (dontEncrypt(haber)) {
            byte[] message = haber.encode();
            Log.d(TAG, "write unencrypted " + message.length + " bytes for " + haber.which + " to " + haber.to);
            network.send(haber.encode());
            return;
        }
        try {
            ByteString encrypted = ByteString.of(crypto.encrypt(bytes, haber.to));
                Log.d(TAG, "write encrypted " + encrypted.size() + " bytes for " + haber.which + " to " + haber.to);
                Haber.Builder payloadBuilder = new Haber.Builder().which(PAYLOAD).payload(encrypted).to(haber.to);
                byte[] payload = payloadBuilder.build().encode();
                network.send(payload);
        } catch (Exception exception) {
            BaseActivity.snackbar(exception.getLocalizedMessage());
        }
    }

    // send to Network

    public void login(String username) {
        Haber.Builder haber = new Haber.Builder().which(LOGIN).login(username);
        instance.send(haber);
    }

    public void sendContacts(List<Contact> contacts) {
        Haber.Builder haber = new Haber.Builder().which(CONTACTS).contacts(contacts);
        instance.send(haber);
    }

    public void sendText(String recipient, String message) {
        okio.ByteString text = okio.ByteString.encodeUtf8(message);
        Haber.Builder haber = new Haber.Builder().which(TEXT).payload(text).to(recipient);
        instance.send(haber);
    }

    void sendPublicKey(byte[] key, String recipient, Boolean isResponse) {
        Haber.Which which = isResponse ? PUBLIC_KEY_RESPONSE : PUBLIC_KEY;
        sendData(which, key, recipient);
    }

    private void sendData(Haber.Which which, byte[] data, String recipient) {
        okio.ByteString byteString = ByteString.of(data);
        Haber.Builder haber = new Haber.Builder().which(which).payload(byteString).to(recipient);
        instance.send(haber);
    }

    void sendHandshake(byte[] key, String recipient) {
        sendData(HANDSHAKE, key, recipient);
    }

    void handshook(String peerId) {
        ArrayList<Haber> list = queue.get(peerId);
        if (list == null) {
            return;
        }
        for (Haber haber: list) {
            send(haber);
        }
    }
}