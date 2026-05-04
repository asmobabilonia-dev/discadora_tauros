[general]
enabled = yes
webenabled = no
port = {{AMI_PORT}}
bindaddr = 0.0.0.0
displayconnects = yes
allowmultiplelogin = yes

[{{AMI_USER}}]
secret = {{AMI_SECRET}}
deny = 0.0.0.0/0.0.0.0
permit = {{PANEL_AMI_ALLOW_IP}}/255.255.255.255
read = system,call,log,verbose,command,agent,user,config,dtmf,reporting,cdr,dialplan,originate
write = system,call,log,verbose,command,agent,user,config,dtmf,reporting,cdr,dialplan,originate

