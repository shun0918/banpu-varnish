FROM varnish:6.2

COPY ./vcl/default.vcl /etc/varnish/