package red.tel.chat;

import android.app.IntentService;
import android.content.Intent;
import android.util.Log;

import com.neovisionaries.ws.client.ProxySettings;
import com.neovisionaries.ws.client.WebSocket;
import com.neovisionaries.ws.client.WebSocketAdapter;
import com.neovisionaries.ws.client.WebSocketException;
import com.neovisionaries.ws.client.WebSocketFactory;
import com.neovisionaries.ws.client.WebSocketFrame;

import java.util.List;
import java.util.Map;

import red.tel.chat.generated_protobuf.Haber;
import red.tel.chat.generated_protobuf.Login;

import static red.tel.chat.generated_protobuf.Haber.Which.LOGIN;

public class Backend extends IntentService {

    private static final String serverUrl = "ws://10.0.0.33:8000/ws";
    private static final String TAG = "Backend";
    private WebSocket webSocket;

    private static Backend shared;

    public Backend() {
        super(TAG);
    }

    @Override
    protected void onHandleIntent(Intent workIntent) {
        shared = this;
        String dataString = workIntent.getDataString();

        WebSocketFactory factory = new WebSocketFactory();
        ProxySettings settings = factory.getProxySettings();
        settings.setServer(serverUrl);
        try {
            webSocket = new WebSocketFactory().createSocket(serverUrl);
            webSocket.addListener(webSocketAdapter);
            webSocket.connectAsynchronously();
        } catch (Exception e) {
            e.printStackTrace();
        }
    }

    public void send(Haber haber) {
        byte[] bytes = Haber.ADAPTER.encode(haber);
        webSocket.sendBinary(bytes);
    }

    private WebSocketAdapter webSocketAdapter = new WebSocketAdapter() {
        @Override public void onConnected(WebSocket websocket, Map<String, List<String>> headers) throws Exception {
            Log.i(TAG, "Connected");
        }
        @Override public void onConnectError(WebSocket websocket, WebSocketException cause) throws Exception {
            Log.e(TAG, "Connect error");
        }
        @Override public void onDisconnected(WebSocket websocket, WebSocketFrame serverCloseFrame, WebSocketFrame clientCloseFrame, boolean closedByServer) throws Exception {
            Log.i(TAG, "Disconnected");
        }
        @Override public void onBinaryMessage(WebSocket websocket, byte[] binary) throws Exception {
            Log.i(TAG, "onBinaryMessage " + binary.length + " bytes");
            Haber haber = Haber.ADAPTER.decode(binary);
            Model.incoming(haber);
        }
    };

    public interface Result {
        void done(Boolean success);
    }

    public static void login(String username, Result result) {
        Login login = new Login.Builder().username(username).build();
        Haber haber = new Haber.Builder().which(LOGIN).login(login).build();
        shared.send(haber);
        result.done(true);
    }
}
