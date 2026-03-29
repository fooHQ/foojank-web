CONTENT_DIR="content"
OUTPUT_DIR="static"

get_mds() {
    find "$CONTENT_DIR" -type f -name "*.md"
}

get_template() {
   awk '/^template:/ { print $2; found=1; exit }
           END { if (!found) print "default.html" }' "$1"
}

while read input
do
    output="${input#*/}"
    output="$OUTPUT_DIR/${output%.md}.html"
    template="$(get_template "$input")"
    echo "Building $input => $output (template: $template)"
    mkdir -p "$(dirname "$output")" && pandoc -d default.yaml --template "$template" -o "$output" "$input"
done < <(get_mds)
