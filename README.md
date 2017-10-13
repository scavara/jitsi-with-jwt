# jitsi-with-jwt
Docker container for setting up jitsi meet with jwt token authentication 
 - ```git clone https://github.com/scavara/jitsi-with-jwt.git && cd jitsi-with-jwt```
 - populate with right files (certs, favicon and watermark) and edit ENVS and top portion of Dockerfile accordingly 
 - build image 
 ```docker build -t jitsi-with-jwt:1.0 .```
 - run container with -it
 ```docker run --rm -it --net=host --hostname=example.com --name=jitsi-with-jwt --env-file=ENVS jitsi-with-jwt:1.0```
 - within container run /run.sh and cross your fingers.
 
Hostory dump for setting up jwt tokens - php example
 ```
 $ cd /usr/src
 $ sudo apt-get install curl php5-cli
 $ curl -sS https://getcomposer.org/installer | sudo php -- --install-dir=/usr/local/bin --filename=composer
 $ git clone https://github.com/lcobucci/jwt.git
 $ cd jwt/
 $ composer require lcobucci/jwt
 $ pwd 
 /home/scavara
 $ cat jwtgen.php
 <?php
 error_reporting(1);
 require '/home/scavara/jwt/vendor/autoload.php';
 use Lcobucci\JWT\Builder;
 use Lcobucci\JWT\Signer\Hmac\Sha256;
 
 $signer = new Sha256();
 
 $jwt_token = (new Builder())->setIssuer('your_app_id') // Configures the issuer (iss claim)
                         ->setAudience('example.com') // Configures the audience (aud claim)
                         ->setId('4f1g23a12aa', true) // Configures the id (jti claim), replicating as a header item
                         ->setIssuedAt(time()) // Configures the time that the token was issue (iat claim)
                         ->setNotBefore(time()) //+ 60) // Configures the time that the token can be used (nbf claim)
                         ->setExpiration(time() + 3600) // Configures the expiration time of the token (nbf claim)
                         ->set('uid', 1) // Configures a new claim, called "uid"
                         ->set('room','conference')
                         ->sign($signer, 'your_app_secret')
                         ->getToken(); // Retrieves the generated token
 ?>
 $ php jwtgen.php 
 ```

