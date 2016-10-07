FROM debian
RUN apt-get update
RUN apt-get install -qqy x11-apps xauth xterm

COPY entrypoint.sh /

ENV DISPLAY :0
ENV COOKIE some magic X11 cookie

ENTRYPOINT [ "/entrypoint.sh" ]
