Per motivi di sicurezza il repo git NON contiene i file .crt .key
Occorree quindi autogenerarli con:
sudo openssl req -x509 -nodes -days 365 -newkey rsa:2048 -keyout nginx/ssl/nome_istanza.key -out nginx/ssl/nome_istanza.crt

