vcl 4.1;

# X-Forwarded-For : クライアントの元ip情報。varnish経由でnginxにリクエストを送ると、logのクライアント元情報がvarnish飲みになってしまう。
# そのため、元のクライアントipも持たせてあげる必要あり
# 参考：https://developer.mozilla.org/ja/docs/Web/HTTP/Headers/X-Forwarded-For

backend default {
    .host = "nginx";
    .port = "80";
}


sub vcl_recv {

    if (req.restarts == 0) {
        if (req.http.x-forwarded-for) {
            set req.http.X-Forwarded-For =
            req.http.X-Forwarded-For + ", " + client.ip;
        } else {
            set req.http.X-Forwarded-For = client.ip;
        }
    }

	if (req.method != "GET" &&
        req.method != "HEAD" &&
        req.method != "PUT" &&
        req.method != "POST" &&
        req.method != "TRACE" &&
        req.method != "OPTIONS" &&
        req.method != "DELETE") {
        /* Non-RFC2616 or CONNECT which is weird. */
        return (pipe);
	}

	if (req.method != "GET" && req.method != "HEAD") {
		/* We only deal with GET and HEAD by default */
        return (pass);
	}

    if ( req.url ~ "\.(png|gif|jpg|jpeg|js|css)$" ) {
        /*  */
        unset req.http.Cookie;
    }

	if (req.http.Authorization || req.http.Cookie) {
        /* Not cacheable by default */
        return (pass);
	}

	return (hash);

}

sub vcl_pipe {
    return (pipe);
}

sub vcl_pass {
    return (fetch);
}

sub vcl_miss {
    return (fetch);
}

sub vcl_hash {
    hash_data(req.url);
    if (req.http.host) {
        hash_data(req.http.host);
    } else {
        hash_data(server.ip);
    }
    # request url とデバイス種別をキーにしてキャッシュ生成
    # hash_data(req.url);
    # hash_data(req.http.X-UA-Device);
    return (lookup);
}

sub vcl_backend_fetch {
    if (bereq.method == "GET") {
        unset bereq.body;
    }
    return (fetch);
}


sub vcl_backend_response {
    # Happens after we have read the response headers from the backend.
    #
    # Here you clean the response headers, removing silly Set-Cookie headers
    # and other mistakes your backend does.

    # backend から送られた Vary Http Header を別の変数に退避して一度削除
    set beresp.http.X-Vary = beresp.http.Vary;
    unset beresp.http.Vary;

    # 404 or 500 等はキャッシュしない
    if (! (beresp.status == 200 || beresp.status == 304)) {
        set beresp.uncacheable = true;
        return (deliver);
    }

    if (bereq.uncacheable) {
        return (deliver);
    } else if (beresp.ttl <= 0s ||
      beresp.http.Set-Cookie ||
      beresp.http.Surrogate-control ~ "(?i)no-store" ||
      (!beresp.http.Surrogate-Control &&
        beresp.http.Cache-Control ~ "(?i:no-cache|no-store|private)") ||
        beresp.http.Vary == "*") {
        set beresp.ttl = 120s;
        set beresp.uncacheable = true;
    }

    set beresp.http.Cache-Control = "public, max-age=86400";

    # cache set the clients TTL on this object /
    set beresp.ttl = 86400s;

    # 圧縮されてない場合圧縮する
    set beresp.do_gzip = true;

    return(deliver);
}

sub vcl_backend_error {
    set beresp.http.Content-Type = "text/html; charset=utf-8";
    set beresp.http.Retry-After = "5";
    set beresp.body = {"<!DOCTYPE html>
<html>
  <head>
    <title>"} + beresp.status + " " + beresp.reason + {"</title>
  </head>
  <body>
    <h1>Error "} + beresp.status + " " + beresp.reason + {"</h1>
    <p>"} + beresp.reason + {"</p>
    <h3>Guru Meditation:</h3>
    <p>XID: "} + bereq.xid + {"</p>
    <hr>
    <p>Varnish cache server</p>
  </body>
</html>
"};
    return (deliver);
}


sub vcl_deliver {
    # Happens when we have all the pieces we need, and are about to send the
    # response to the client.
    #
    # You can do accounting or modifying the final object here.

    if (obj.hits > 0) {
        set resp.http.X-Cache = "HIT";
    } else {
        set resp.http.X-Cache = "MISS";
    }

    # 退避したVaryヘッダを復元
    set resp.http.Vary = resp.http.X-Vary;
    unset resp.http.X-Vary;

    unset resp.http.Via;
    unset resp.http.X-Varnish;
    unset resp.http.X-Served-by;
}
