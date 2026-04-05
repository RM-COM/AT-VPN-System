#!/bin/bash
### https://github.com/GFW4Fun
Green="\033[32m"
Red="\033[31m"
Yellow="\033[33m"
Blue="\033[36m"
Font="\033[0m"
OK="${Green}[OK]${Font}"
ERROR="${Red}[ERROR]${Font}"
function msg_inf() {  echo -e "${Blue} $1 ${Font}"; }
function msg_ok() { echo -e "${OK} ${Blue} $1 ${Font}"; }
function msg_err() { echo -e "${ERROR} ${Yellow} $1 ${Font}"; }
SCRIPT_SOURCE="${BASH_SOURCE[0]}"
SCRIPT_DIR=$(cd -- "$(dirname -- "$SCRIPT_SOURCE")" >/dev/null 2>&1 && pwd -P)
TEMPLATES_DIR="$SCRIPT_DIR/fake-site/templates"
EXCLUDED_TEMPLATES=(
	"coming-soon-responsive-theme-jack"
	"css3-drop-shadows"
)

install_fallback_template() {
	mkdir -p /var/www/html
	cat > /var/www/html/index.html <<'EOF'
<!doctype html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width,initial-scale=1">
  <title>Edge Service</title>
  <style>
    body {
      margin: 0;
      min-height: 100vh;
      display: grid;
      place-items: center;
      font-family: Arial, sans-serif;
      background: radial-gradient(circle at top, #1d4ed8, #0f172a 60%);
      color: #eff6ff;
    }
    main {
      width: min(92vw, 720px);
      padding: 36px;
      border-radius: 28px;
      background: rgba(15, 23, 42, 0.86);
      box-shadow: 0 32px 90px rgba(15, 23, 42, 0.45);
    }
    h1 { margin: 0 0 12px; }
    p { line-height: 1.7; color: #cbd5e1; }
  </style>
</head>
<body>
  <main>
    <h1>Edge Service</h1>
    <p>The node is reachable and operating normally.</p>
    <p>This page is intentionally minimal and is served from the local repository bundle.</p>
  </main>
</body>
</html>
EOF
}

if [[ ! -d "$TEMPLATES_DIR" ]]; then
	msg_err "Local fake-site templates not found, installing fallback page"
	install_fallback_template
	exit 0
fi

mapfile -t template_dirs < <(
	find "$TEMPLATES_DIR" -mindepth 1 -maxdepth 1 -type d | while IFS= read -r dir; do
		base=$(basename "$dir")
		skip=0
		for excluded in "${EXCLUDED_TEMPLATES[@]}"; do
			if [[ "$base" == "$excluded" ]]; then
				skip=1
				break
			fi
		done
		(( skip )) || printf '%s\n' "$dir"
	done | sort
)

if [[ ${#template_dirs[@]} -eq 0 ]]; then
	msg_err "No local fake-site templates found, installing fallback page"
	install_fallback_template
	exit 0
fi

RandomTemplate="${template_dirs[$((RANDOM % ${#template_dirs[@]}))]}"
msg_inf "Random template name: $(basename "$RandomTemplate")"

if [[ -d "$RandomTemplate" ]]; then
	mkdir -p /var/www/html
	rm -rf /var/www/html/*
	cp -a "$RandomTemplate/." "/var/www/html/"
	msg_ok "Template extracted successfully!"
else
	msg_err "Extraction error!"
	exit 1
fi
