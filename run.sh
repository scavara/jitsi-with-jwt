# !/bin/bash
#apache will complain a bit if something like this is not in hosts
echo "127.0.1.1		$DOMAIN" >> /etc/hosts

#setup certs
cd /var/lib/prosody/
cp $KEY $DOMAIN.key
cat $CRT $CA > $DOMAIN.crt
chown root:prosody $DOMAIN.key localhost.key
chmod 640 $DOMAIN.key localhost.key
cd /etc/prosody/certs/
for i in crt key; do ln -s /var/lib/prosody/$DOMAIN.$i $DOMAIN.$i;done

#configure prosody
cd /etc/prosody
sed -i 's/c2s_require_encryption\ =\ true/c2s_require_encryption\ =\ false/g' prosody.cfg.lua
echo 'Include "conf.d/*.cfg.lua"' >> prosody.cfg.lua
sed -i '/VirtualHost "localhost"/a \\t enable = false' prosody.cfg.lua
cd /etc/prosody/conf.avail
echo 'plugin_paths = { "/usr/share/jitsi-meet/prosody-plugins/" }
VirtualHost "'$DOMAIN'"
        -- enabled = false -- Remove this line to enable this host
        authentication = "token"
        -- Properties below are modified by jitsi-meet-tokens package config
        -- and authentication above is switched to "token"
        app_id="'$APPID'"
        app_secret="'$APPSECRET'"
        -- Assign this host a certificate for TLS, otherwise it would use the one
        -- set in the global section (if any).
        -- Note that old-style SSL on port 5223 only supports one certificate, and will always
        -- use the global one.
        ssl = {
                key = "/etc/prosody/certs/'$DOMAIN'.key";
                certificate = "/etc/prosody/certs/'$DOMAIN'.crt";
        }
        -- we need bosh
        modules_enabled = {
            "bosh";
            "pubsub";
            "ping"; -- Enable mod_ping
        }

        c2s_require_encryption = false

Component "conference.'$DOMAIN'" "muc"
        storage = "null"
        modules_enabled = { "token_verification" }
        admins = { "focus@auth.'$DOMAIN'" }

Component "jitsi-videobridge.'$DOMAIN'"
    component_secret = "'$JVBSECRET'"

VirtualHost "auth.'$DOMAIN'"
    authentication = "internal_plain"

Component "focus.'$DOMAIN'"
    component_secret = "'$JICOFOSECRET'"

Component "callcontrol.'$DOMAIN'" 
    component_secret = "'$JIGASISECRET'"'  > $DOMAIN.cfg.lua

ln -s /etc/prosody/conf.avail/$DOMAIN.cfg.lua /etc/prosody/conf.d/$DOMAIN.cfg.lua

#configure meet
cd /etc/jitsi/meet
mv ok-config.js $DOMAIN-config.js
sed -i "s/domain:\ 'ok'/domain:\ '$DOMAIN'/g" $DOMAIN-config.js
sed -i "s/\/\/authdomain: '$DOMAIN'/authdomain:\ 'auth.$DOMAIN'/g" $DOMAIN-config.js
sed -i "s/muc:\ 'conference.ok'/muc:\ 'conference.$DOMAIN'/g" $DOMAIN-config.js
sed -i "s/\/\/focus:\ 'focus.ok'/focus:\ 'focus.$DOMAIN'/g" $DOMAIN-config.js
sed -i "s/bosh:\ '\/\/ok\/http-bind',/bosh: '\/\/$DOMAIN\/http-bind',/g" $DOMAIN-config.js

#configure jvb
cd /etc/jitsi/videobridge
sed -i "s/JVB_HOSTNAME=/JVB_HOSTNAME=$DOMAIN/g" config
sed -i "/^JVB_SECRET=/s/=.*/=$JVBSECRET/g" config

#needed if lib-jitsi-meet is used...
sed -i 's/JVB_OPTS=""/JVB_OPTS="--apis=xmpp,rest"/g' config
echo "org.jitsi.videobridge.AUTHORIZED_SOURCE_REGEXP=focus@auth.$DOMAIN/.*" > sip-communicator.properties
echo "org.ice4j.ipv6.DISABLED=true" >> sip-communicator.properties

#configure jicofo
cd /etc/jitsi/jicofo
sed -i "/^JICOFO_HOSTNAME=/s/=.*/=$DOMAIN/g" config
sed -i "/^JICOFO_SECRET=/s/=.*/=$JICOFOSECRET/g" config
sed -i "/^JICOFO_AUTH_DOMAIN=/s/=.*/=auth.$DOMAIN/g" config
sed -i "/^JICOFO_AUTH_PASSWORD=/s/=.*/=$JICOFOAUTHPASSWORD/g" config

#configure jigasi
cd /etc/jitsi/jigasi
sed -i "/^JIGASI_SIPUSER=/s/=.*/=$JIGASISIPUSER/g" config
sed -i "/^JIGASI_SIPPWD=/s/=.*/=$JIGASISIPPWDBASE64/g" config
sed -i "/^JIGASI_SECRET=/s/=.*/=$JIGASISECRET/g" config
sed -i "/^JIGASI_HOSTNAME=/s/=.*/=$DOMAIN/g" config

sed -i "/DEFAULT_JVB_ROOM_NAME=/s/=.*/=defaultroom@conference.$DOMAIN/g" sip-communicator.properties
sed -i "/ACCOUNT_UID=/s/=.*/=SIP\\\:$JIGASISIPUSER/g" sip-communicator.properties
sed -i "/PASSWORD=/s/=.*/=$JIGASISIPPWD/g" sip-communicator.properties
sed -i "/SERVER_ADDRESS=/s/=.*/=$JIGASISIPSERVER/g" sip-communicator.properties
sed -i "/^net.java.sip.communicator.impl.protocol.sip.*USER_ID=/s/=.*/=$JIGASISIPUSER/g" sip-communicator.properties

prosodyctl register $JIGASILOCALUSER  auth.$DOMAIN $JIGASISIPPWD

sed -i "s/# org.jitsi.jigasi.xmpp.acc.USER_ID.*/org.jitsi.jigasi.xmpp.acc.USER_ID=$JIGASILOCALUSER@auth.$DOMAIN/g" sip-communicator.properties
sed -i "s/# org.jitsi.jigasi.xmpp.acc.PASS.*/org.jitsi.jigasi.xmpp.acc.PASS=$JIGASISIPPWD/g" sip-communicator.properties
sed -i "/^# org.jitsi.jigasi.xmpp.acc.ANONYMOUS_AUTH=false/s/#//g" sip-communicator.properties

#configure apache
a2dissite ok
cd /etc/apache2/sites-available
mv ok.conf $DOMAIN.conf
sed -i "s/ServerName ok/ServerName $DOMAIN/g" $DOMAIN.conf
sed -i "s@SSLCertificateFile /etc/jitsi/meet/ok.crt@SSLCertificateFile $CRT@g" $DOMAIN.conf
sed -i "s@SSLCertificateKeyFile /etc/jitsi/meet/ok.key@SSLCertificateKeyFile $KEY@g" $DOMAIN.conf
sed -i "/SSLCertificateKeyFile/a \  SSLCertificateChainFile $CA" $DOMAIN.conf
sed -i "s@Alias \"/config.js\" \"/etc/jitsi/meet/ok-config.js\"@Alias \"/config.js\" \"/etc/jitsi/meet/$DOMAIN-config.js\"@g" $DOMAIN.conf
echo 'Header always set Access-Control-Allow-Origin "*"  
Header always set Access-Control-Allow-Methods "POST, GET, OPTIONS, DELETE, PUT" 
Header always set Access-Control-Max-Age "1000" 
Header always set Access-Control-Allow-Headers "x-requested-with, Content-Type, origin, authorization, accept, client-security-token"' >> $DOMAIN.conf
a2ensite $DOMAIN

# customize jitsi-meet web (TODO)
cp /tmp/favicon.ico /usr/share/jitsi-meet/images/
cp /tmp/watermark.png /usr/share/jitsi-meet/images/

#add to prosodoy focus user
prosodyctl register focus auth.$DOMAIN $JICOFOAUTHPASSWORD

#clean up
rm /tmp/*.*

#restart services
service apache2 start && service prosody start && service jitsi-videobridge start && service jicofo start && service jigasi start

tail -f /var/log/prosody/prosody.log /var/log/jitsi/jvb.log /var/log/jitsi/jicofo.log | grep -vi 'FINE\|INFO'
