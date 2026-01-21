async function callBackend() {
    const responseDiv = document.getElementById('response');
    try {
        const res = await fetch('/api');
        const data = await res.json();
        responseDiv.textContent = JSON.stringify(data, null, 2);
    } catch (err) {
        responseDiv.textContent = 'Error: ' + err.message;
    }
}
