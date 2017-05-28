package red.tel.chat;

import android.util.Log;
import java.util.List;
import java.util.Map;

import com.neovisionaries.ws.client.ProxySettings;
import com.neovisionaries.ws.client.WebSocket;
import com.neovisionaries.ws.client.WebSocketAdapter;
import com.neovisionaries.ws.client.WebSocketException;
import com.neovisionaries.ws.client.WebSocketFactory;
import com.neovisionaries.ws.client.WebSocketFrame;

// websocket façade
class Network {

    private static final String serverUrl = "ws://10.0.0.33:8000/ws";
    private static final String TAG = "Backend";
    private WebSocket webSocket;

    Network() {

        WebSocketFactory factory = new WebSocketFactory();
        ProxySettings settings = factory.getProxySettings();
        settings.setServer(serverUrl);

        try {
            WebSocketAdapter webSocketAdapter = new WebSocketAdapter() {
                @Override
                public void onConnected(WebSocket websocket, Map<String, List<String>> headers) throws Exception {
                    Log.i(TAG, "Connected");
                }

                @Override
                public void onConnectError(WebSocket websocket, WebSocketException cause) throws Exception {
                    Log.e(TAG, "Connect error");
                }

                @Override
                public void onDisconnected(WebSocket websocket, WebSocketFrame serverCloseFrame, WebSocketFrame clientCloseFrame, boolean closedByServer) throws Exception {
                    Log.i(TAG, "Disconnected");
                }

                @Override
                public void onBinaryMessage(WebSocket websocket, byte[] binary) throws Exception {
                    Log.i(TAG, "onBinaryMessage " + binary.length + " bytes");
                    Backend.incoming(binary);
                }
            };

            webSocket = new WebSocketFactory().createSocket(serverUrl);
            webSocket.addListener(webSocketAdapter);
            webSocket.connectAsynchronously();

        } catch (Exception e) {
            e.printStackTrace();
        }
    }

    void send(byte[] bytes) {
        webSocket.sendBinary(bytes);
    }
}