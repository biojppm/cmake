set -x

function dl()
{
    url=$1
    name=$2
    if [ "$name" == "" ] ; then
        name=$(basename "$url")
    fi
    curl -L "$url" > "$name"
}

dl "https://code.jquery.com/jquery-3.3.1.js"
dl "https://code.jquery.com/jquery-3.3.1.min.js"

dl "https://cdn.datatables.net/1.10.20/js/jquery.dataTables.js"
dl "https://cdn.datatables.net/1.10.20/js/jquery.dataTables.min.js"
dl "https://cdn.datatables.net/1.10.20/css/jquery.dataTables.css"
dl "https://cdn.datatables.net/1.10.20/css/jquery.dataTables.min.css"

dl "https://www.chartjs.org/dist/2.9.1/Chart.min.js"

dl "https://cdnjs.cloudflare.com/ajax/libs/highlight.js/9.15.10/styles/github.css" "highlight.github.css"
dl "https://cdnjs.cloudflare.com/ajax/libs/highlight.js/9.15.10/styles/github.min.css" "highlight.github.min.css"
dl "https://cdnjs.cloudflare.com/ajax/libs/highlight.js/9.15.10/highlight.js"
dl "https://cdnjs.cloudflare.com/ajax/libs/highlight.js/9.15.10/highlight.min.js"
