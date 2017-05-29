package red.tel.chat.ui;

import android.support.v7.app.AppCompatActivity;
import android.content.Context;

public class BaseActivity extends AppCompatActivity {

    private static BaseActivity current;

    @Override
    protected void onResume() {
        super.onResume();
        current = this;
    }

    @Override
    protected void onPause() {
        super.onPause();
        current = null;
    }

    public static Context getCurrentContext() {
        return current;
    }
}
