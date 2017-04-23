package x.ws2;

import com.google.gson.Gson;
import com.google.gson.JsonObject;
import com.google.gson.annotations.SerializedName;

/**
 * Created by yusuf_saib on 3/5/17.
 */

public class RealTimeEvent {

  String userId;

  @SerializedName("event")
  private int event;

  @SerializedName("params")
  private JsonObject params;

  public int getType() {
    return event;
  }

  public String getUserId() {
    return userId;
  }

  public <T> T getParams(Class<T> type) {
    return new Gson().fromJson(params.toString(), type);
  }
}