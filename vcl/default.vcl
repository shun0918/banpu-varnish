vcl 4.0;

# X-Forwarded-For : クライアントの元ip情報。varnish経由でnginxにリクエストを送ると、logのクライアント元情報がvarnish飲みになってしまう。
# そのため、元のクライアントipも持たせてあげる必要あり
# 参考：https://developer.mozilla.org/ja/docs/Web/HTTP/Headers/X-Forwarded-For

backend default {
	.host = "nginx";
	.port = "80"
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

	if (req.request != "GET" &&
		req.request != "HEAD" &&
		req.request != "PUT" &&
		req.request != "POST" &&
		req.request != "TRACE" &&
		req.request != "OPTIONS" &&
		req.request != "DELETE") {
		/* Non-RFC2616 or CONNECT which is weird. */
		return (pipe);
	}

	if (req.request != "GET" && req.request != "HEAD") {
		/* We only deal with GET and HEAD by default */
		return (pass);
	}
	if (req.http.Authorization || req.http.Cookie) {
		/* Not cacheable by default */
		return (pass);
	}
	return (lookup);

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



sub vcl_backend_response {

}

sub vcl_deliver {

}