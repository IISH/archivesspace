AS_ENDPOINT='http://localhost:4567'
AS_USER='admin'
AS_PASSWORD='admin'

function as_session() {
	f="${HOME}/.session"
	[ -f "$f" ] && SESSION=$(cat "$f")
	[ -z "$token" ] && SESSION=$(curl -Fpassword=${AS_PASSWORD} "${AS_ENDPOINT}/users/${AS_USER}/login" | jq -r '.session')
	export SESSION
	echo -n "$SESSION" > "$f"
	echo -n "$SESSION"
}
SESSION=$(as_session) && echo "Session token: ${SESSION}"
echo "curl -H 'X-ArchivesSpace-Session: ${SESSION}'"
