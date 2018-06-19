#!/bin/bash

# Create chef-server.rb with variables
echo "nginx['enable_non_ssl']=false" > /etc/opscode/chef-server.rb

if [[ -z $SSL_PORT ]]; then
  echo "nginx['ssl_port']=443" >> /etc/opscode/chef-server.rb
else
  echo "nginx['ssl_port']=$SSL_PORT" >> /etc/opscode/chef-server.rb
fi

if [[ -z $CONTAINER_NAME ]]; then
  chefFQDN=$(uname -n)
  echo "nginx['server_name']=\"chef-server\"" >> /etc/opscode/chef-server.rb
else
  chefFQDN="$CONTAINER_NAME"
  echo "nginx['server_name']=\"$CONTAINER_NAME\"" >> /etc/opscode/chef-server.rb
fi

echo -e "\nRunning: 'chef-server-ctl reconfigure'. This step will take a few minutes..."
chef-server-ctl reconfigure

URL="http://127.0.0.1:8000/_status"
CODE=1
SECONDS=0
TIMEOUT=60

return=$(curl -sf ${URL})

if [[ -z "$return" ]]; then
  echo -e "\nINFO: Chef-Server isn't ready yet!"
  echo -e "Blocking until <${URL}> responds...\n"

  while [ $CODE -ne 0 ]; do

    curl -sf \
         --connect-timeout 3 \
         --max-time 5 \
         --fail \
         --silent \
         ${URL}

    CODE=$?

    sleep 2
    echo -n "."

    if [ $SECONDS -ge $TIMEOUT ]; then
      echo "$URL is not available after $SECONDS seconds...stopping the script!"
      exit 1
    fi
  done;
fi

echo -e "\n\n$URL is available!\n"
echo -e "\nSetting up admin user and default organization"

if [[ -z $CHEF_MAIL ]]; then
  chefMail="admin@$chefFDQN";
else
  chefMail="$CHEF_MAIL"
fi


if [[ -z $CHEF_USER ]]; then
  chefUser="admin";
else
  chefUser="$CHEF_USER"
fi

if [[ -z $CHEF_PASS ]]; then
  chefPass=$(strings /dev/urandom | grep -o '[[:alnum:]]' | head -n 32 | tr -d '\n'; echo)
  echo "$chefPass" >> /etc/chef/chefUserPass.txt 
else
  chefPass="$CHEF_PASS";
fi

chef-server-ctl user-create "$chefUser" "$chefUser" "User" "$chefMail" "$chefPass"  --filename "/etc/chef/$chefUser.pem"

if [[ -z $CHEF_ORG ]]; then
  chefOrg="my_org";
else
  chefOrg="$CHEF_ORG"
fi

if [[ -z $CHEF_ORGDESC ]]; then
  chefOrgDesc="Default organization"
else
  chefOrgDesc="$CHEF_ORGDESC";
fi

chef-server-ctl org-create "$chefOrg" "$chefOrgDesc" --association_user "$chefUser" --filename "/etc/chef/$chefOrg-validator.pem"
echo -e "\nRunning: 'chef-server-ctl install chef-manage'"...
chef-server-ctl install chef-manage
echo -e "\nRunning: 'chef-server-ctl reconfigure'"...
chef-server-ctl reconfigure
echo "{ \"error\": \"Please use https:// instead of http:// !\" }" > /var/opt/opscode/nginx/html/500.json
sed -i "s,/503.json;,/503.json;\n    error_page 497 =503 /500.json;,g" /var/opt/opscode/nginx/etc/chef_https_lb.conf
echo -e "\nRestart Nginx..."
chef-server-ctl restart nginx
chef-server-ctl status
touch /root/chef_configured
echo -e "\n\nDone!\n"
