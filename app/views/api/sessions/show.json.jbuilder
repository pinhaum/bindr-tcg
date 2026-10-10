json.data do
  json.partial! "api/sessions/session", user: user, csrf_token: csrf_token
end
