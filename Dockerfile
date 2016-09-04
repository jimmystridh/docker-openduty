FROM ubuntu:14.04
MAINTAINER Jimmy Stridh <jimmy@stridh.nu>
RUN apt-get update
RUN apt-get -y upgrade
RUN apt-get -y install supervisor
RUN apt-get -y install git python-pip python-dev build-essential g++ libbz2-dev libncurses5-dev libreadline-dev libsqlite3-dev libssl-dev libxml2-dev libxslt-dev make zlib1g-dev libmysqlclient-dev libsasl2-dev python-dev libldap2-dev libssl-dev
RUN git clone https://github.com/ustream/openduty.git /opt/openduty
RUN cd /opt/openduty && pip install -r requirements.txt
RUN cd /opt/openduty && pip install gunicorn

ADD supervisord.conf /etc/supervisor/conf.d/supervisord.conf
ADD start_openduty.sh /opt/openduty

EXPOSE 80
CMD ["/usr/bin/supervisord"]
