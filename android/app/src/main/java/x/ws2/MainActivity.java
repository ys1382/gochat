package x.ws2;

import android.os.Bundle;
import android.support.v7.app.AppCompatActivity;
import android.view.View;
import android.widget.Button;
import android.widget.TextView;

import org.greenrobot.eventbus.EventBus;
import org.greenrobot.eventbus.Subscribe;

public class MainActivity extends AppCompatActivity {

  private ExampleSocketConnection exampleSocketConnection;

  @Override
  protected void onCreate(Bundle savedInstanceState) {
    super.onCreate(savedInstanceState);
    setContentView(R.layout.activity_main);

    Button sendText = (Button) findViewById(R.id.send_text);
    TextView userInput = (TextView) findViewById(R.id.message);
    sendText.setOnClickListener(new View.OnClickListener() {
      @Override
      public void onClick(View view) {
        String message = userInput.getText().toString();
        exampleSocketConnection.sendMessage(message);
      }
    });

    exampleSocketConnection = new ExampleSocketConnection(this);
//    BackgroundManager.get(this.getApplication()).registerListener(appActivityListener);
    this.openSocketConnection();
  }

  public void closeSocketConnection() {
    exampleSocketConnection.closeConnection();
  }

  public void openSocketConnection() {
    exampleSocketConnection.openConnection();
  }

  public boolean isSocketConnected() {
    return exampleSocketConnection.isConnected();
  }

  public void reconnect() {
    exampleSocketConnection.openConnection();
  }

  @Override
  protected void onStart() {
    super.onStart();
    EventBus.getDefault().register(this);
  }

  @Override
  protected void onStop() {
    EventBus.getDefault().unregister(this);
    super.onStop();
  }

  @Subscribe
  public void handleRealTimeMessage(RealTimeEvent event) {
    // processing of all real-time events
  }
}
