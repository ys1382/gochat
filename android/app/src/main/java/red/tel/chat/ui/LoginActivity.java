package red.tel.chat.ui;

import android.animation.Animator;
import android.animation.AnimatorListenerAdapter;
import android.content.Intent;
import android.os.Bundle;
import android.support.v7.app.AppCompatActivity;
import android.view.KeyEvent;
import android.view.View;
import android.view.inputmethod.EditorInfo;
import android.widget.Button;
import android.widget.EditText;
import android.widget.TextView;

import red.tel.chat.Model;
import red.tel.chat.Backend;
import red.tel.chat.R;

public class LoginActivity extends AppCompatActivity {

    private static final String TAG = "LoginActivity";
    private EditText usernameView;
    private EditText passwordView;
    private View progressView;
    private View loginFormView;

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        setContentView(R.layout.activity_login);

        usernameView = (EditText) findViewById(R.id.username);
        passwordView = (EditText) findViewById(R.id.password);
        passwordView.setOnEditorActionListener((TextView textView, int id, KeyEvent keyEvent) -> {
            if (id == R.id.login || id == EditorInfo.IME_NULL) {
                validateInput();
                return true;
            }
            return false;
        });

//        Button signInButton = (Button) findViewById(R.id.sign_in_button);
//        signInButton.setOnClickListener((View view) -> { didClickSignIn(); });

        loginFormView = findViewById(R.id.login_form);
        progressView = findViewById(R.id.login_progress);
    }

    private Boolean validateInput() {

        usernameView.setError(null);
        passwordView.setError(null);

        String username = usernameView.getText().toString();
        String password = passwordView.getText().toString();

        if (!isPasswordValid(password)) {
            passwordView.setError(getString(R.string.error_invalid_password));
            passwordView.requestFocus();
            return false;
        }

        if (!isUsernameValid(username)) {
            usernameView.setError(getString(R.string.error_invalid_username));
            usernameView.requestFocus();
            return false;
        }

        return true;
    }

    private boolean isUsernameValid(String username) {
        return username.length() > 0;
    }

    private boolean isPasswordValid(String password) {
        return password.length() > 0;
    }

    private void showProgress(final boolean show) {
        int shortAnimTime = getResources().getInteger(android.R.integer.config_shortAnimTime);

        loginFormView.setVisibility(show ? View.GONE : View.VISIBLE);
        loginFormView.animate().setDuration(shortAnimTime).alpha(
                show ? 0 : 1).setListener(new AnimatorListenerAdapter() {
            @Override
            public void onAnimationEnd(Animator animation) {
                loginFormView.setVisibility(show ? View.GONE : View.VISIBLE);
            }
        });

        progressView.setVisibility(show ? View.VISIBLE : View.GONE);
        progressView.animate().setDuration(shortAnimTime).alpha(
                show ? 1 : 0).setListener(new AnimatorListenerAdapter() {
            @Override
            public void onAnimationEnd(Animator animation) {
                progressView.setVisibility(show ? View.VISIBLE : View.GONE);
            }
        });
    }

    public void onClickSignIn(View v) {
        if (!validateInput()) {
            return;
        }
        String username = usernameView.getText().toString();
        showProgress(true);
        Backend.login(username, (Boolean success) -> {
            Model.setUsername(username);
            startActivity(new Intent(this, ItemListActivity.class));
        });
    }

    public void onClickRegister(View v) {}
}