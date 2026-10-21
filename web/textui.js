const textUIContainer = document.getElementById('textui-container');

export function showTextUI(items = []) {
    if (!items || items.length === 0) {
        items = [{ key: 'E', text: 'Open' }];
    }

    textUIContainer.innerHTML = '';
    document.body.classList.remove('hiding');

    items.forEach((item, index) => {
        const textUIItem = createTextUIItem(item.key, item.text);
        textUIContainer.appendChild(textUIItem);
    });

    document.body.style.visibility = 'visible';
}

export function hideTextUI() {
    document.body.classList.add('hiding');

    setTimeout(() => {
        if (document.body.classList.contains('hiding')) {
            document.body.style.visibility = 'hidden';
            document.body.classList.remove('hiding');
            textUIContainer.innerHTML = '';
        }
    }, 320);
}

export function updateTextUI(items) {
    showTextUI(items);
}

function createTextUIItem(key, text) {
    const item = document.createElement('div');
    item.className = 'textui-item';

    item.innerHTML = `
    <div class="textui-button">
      <div class="textui-button-inner">
        <span class="textui-key">${key}</span>
      </div>
    </div>
    <div class="textui-text">
      <div class="textui-text-inner">
        <span class="textui-label">${text}</span>
      </div>
    </div>
  `;

    return item;
}

window.addEventListener('message', (event) => {
    const data = event.data;

    switch (data.action) {
        case 'showTextUI':
            showTextUI(data.items);
            break;

        case 'hideTextUI':
            hideTextUI();
            break;

        case 'updateTextUI':
            updateTextUI(data.items);
            break;
    }
});
