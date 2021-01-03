FROM varnish:6.5.1-1

COPY ./vcl/default.vcl /etc/varnish/default.vcl

EXPOSE 6081
CMD ["varnishd", "-a", ":8080", "-f", "/etc/varnish/default.vcl", "-F"]