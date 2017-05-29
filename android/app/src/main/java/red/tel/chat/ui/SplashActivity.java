package red.tel.chat.ui;

import android.content.Intent;
import android.os.Bundle;
import android.os.Handler;
import android.support.v7.app.AppCompatActivity;

import java.util.Timer;
import java.util.TimerTask;

import red.tel.chat.Backend;
import red.tel.chat.EventBus;
import red.tel.chat.EventBus.Event;
import red.tel.chat.Model;
import red.tel.chat.R;

public class SplashActivity extends BaseActivity {

    private static final int SPLASH_DURATION = 3000;

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        setContentView(R.layout.activity_splash);

        EventBus.listenFor(this, Event.AUTHENTICATED, () -> {
            timerTask.cancel();
            start(ItemListActivity.class);
        });

        new Timer().schedule(timerTask, SPLASH_DURATION);
    }

    private TimerTask timerTask = new TimerTask() {
        @Override
        public void run() {
            start(LoginActivity.class);
        }
    };

    private void start(Class next) {
        Intent intent = new Intent(this, next);
        intent.setFlags(Intent.FLAG_ACTIVITY_NEW_TASK | Intent.FLAG_ACTIVITY_TASK_ON_HOME);
        startActivity(intent);
        this.finish();
    }
}
