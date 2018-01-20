FROM isuper/java-oracle:server_jre_8

MAINTAINER Richard Rowlands <rrowlands@terraframe.com>

##################
## Configure OS ##
##################

ENV DEBIAN_FRONTEND noninteractive
RUN apt-get -y update
RUN apt-get -y -f upgrade
RUN apt-get -y -f dist-upgrade

RUN apt-get -y -f install vim
RUN apt-get -y -f install wget

####################
## Install Tomcat ##
####################
# https://hub.docker.com/r/openweb/oracle-tomcat/

ENV CATALINA_HOME /usr/local/tomcat
ENV PATH $CATALINA_HOME/bin:$PATH
RUN mkdir -p "$CATALINA_HOME"
WORKDIR $CATALINA_HOME

# see https://www.apache.org/dist/tomcat/tomcat-8/KEYS
RUN set -ex \
  && for key in \
    05AB33110949707C93A279E3D3EFE6B686867BA6 \
    07E48665A34DCAFAE522E5E6266191C37C037D42 \
    47309207D818FFD8DCD3F83F1931D684307A10A5 \
    541FBE7D8F78B25E055DDEE13C370389288584E7 \
    61B832AC2F1C5A90F0F9B00A1C506407564C17A3 \
    79F7026C690BAA50B92CD8B66A3AD3F4F22C4FED \
    80FF76D88A969FE46108558A80B953A041E49465 \
    8B39757B1D8A994DF2433ED58B3A601F08C975E5 \
    A27677289986DB50844682F8ACB77FC2E86E29AC \
    A9C5DF4D22E99998D9875A5110C01C5A2F6059E7 \
    B3F49CD3B9BD2996DA90F817ED3873F5D3262722 \
    DCFD35E0BF8CA7344752DE8B6FB21E8933C60243 \
    F3A04C595DB5B6A5F1ECA43E3B7BBB100D811BBE \
    F7DA48BB64BCB84ECBA7EE6935CD23C10D498E23 \
  ; do \
    gpg --keyserver ha.pool.sks-keyservers.net --recv-keys "$key"; \
  done

ENV TOMCAT_MAJOR 8
ENV TOMCAT_VERSION 8.0.37
ENV TOMCAT_TGZ_URL http://archive.apache.org/dist/tomcat/tomcat-$TOMCAT_MAJOR/v$TOMCAT_VERSION/bin/apache-tomcat-$TOMCAT_VERSION.tar.gz

RUN set -x \
  && curl -fSL "$TOMCAT_TGZ_URL" -o tomcat.tar.gz \
  && curl -fSL "$TOMCAT_TGZ_URL.asc" -o tomcat.tar.gz.asc \
  && gpg --batch --verify tomcat.tar.gz.asc tomcat.tar.gz \
  && tar -xvf tomcat.tar.gz --strip-components=1 \
  && rm bin/*.bat \
  && rm tomcat.tar.gz*

EXPOSE 8080

###################
## Configure SSL ##
###################

ADD security/geoprism.ks $CATALINA_HOME/conf/geoprism.ks
ADD security/geoprism.crt $CATALINA_HOME/conf/geoprism.crt
ADD security/server.xml $CATALINA_HOME/conf/server.xml

RUN $JAVA_HOME/bin/keytool -importcert -alias geoprism -file $CATALINA_HOME/conf/geoprism.crt -keystore $JAVA_HOME/jre/lib/security/cacerts -storepass changeit -noprompt

ADD http://nexus.terraframe.com/service/local/artifact/maven/redirect?r=allrepos&g=com.terraframe&a=credentialsSingleton&p=jar&v=1.0 $CATALINA_HOME/lib/credentialsSingleton.jar
ADD http://nexus.terraframe.com/service/local/artifact/maven/redirect?r=allrepos&g=com.runwaysdk&a=runwaysdk-tomcatcl&p=jar&v=LATEST $CATALINA_HOME/lib/runwaysdk-tomcatcl.jar

EXPOSE 8443

##############################
## Production Tomcat Tweaks ##
##############################
RUN rm -r webapps
RUN mkdir webapps

# Uncomment this if you need to test the docker image with a geoprism instance.
#ADD http://nexus.terraframe.com/service/local/artifact/maven/redirect?r=allrepos&g=net.geoprism&a=geoprism-web&p=war&v=1.01.0006-SNAPSHOT $CATALINA_HOME/webapps/ROOT.war

CMD ["catalina.sh", "run"]
