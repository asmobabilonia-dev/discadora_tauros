[transport-udp]
type=transport
protocol=udp
bind=0.0.0.0:5060
external_media_address={{PUBLIC_IP}}
external_signaling_address={{PUBLIC_IP}}

[transport-ws]
type=transport
protocol=ws
bind=0.0.0.0:{{HTTP_PORT}}
external_media_address={{PUBLIC_IP}}
external_signaling_address={{PUBLIC_IP}}

[magnus-auth]
type=auth
auth_type=userpass
username={{MAGNUS_USER}}
password={{MAGNUS_SECRET}}

[magnus-aor]
type=aor
contact=sip:{{MAGNUS_HOST}}:{{MAGNUS_PORT}}

[magnus]
type=endpoint
transport=transport-udp
context=from-magnus
disallow=all
allow=ulaw,alaw
aors=magnus-aor
outbound_auth=magnus-auth
from_user={{MAGNUS_FROM_USER}}
from_domain={{MAGNUS_FROM_DOMAIN}}
send_pai=yes
send_rpid=yes
trust_id_outbound=yes
direct_media=no
rtp_symmetric=yes
force_rport=yes
rewrite_contact=yes
media_address={{PUBLIC_IP}}

