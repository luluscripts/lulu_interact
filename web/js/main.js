import { createOptions } from "./createOptions.js";
import { fetchNui } from "./fetchNui.js";
import { onSelect } from "./controls.js";
import { setCurrentIndex, resetHold, updateHighlight, setDefaultColor } from "./controls.js";

const optionsWrapper = document.getElementById("options-wrapper");
const body = document.body;

window.addEventListener("message", (event) => {
  switch (event.data.action) {
    case "visible": {
      if (event.data.value) {
        body.classList.remove('hiding');
        body.style.visibility = "visible";
      } else {
        resetHold();
        body.classList.add('hiding');
        setTimeout(() => {
          if (body.classList.contains('hiding')) {
            body.style.visibility = "hidden";
          }
        }, 220);
      }
      break;
    }

    case "setOptions": {
      resetHold();
      optionsWrapper.innerHTML = "";

      const animatedBg = document.createElement("div");
      animatedBg.className = "animated-background";
      optionsWrapper.appendChild(animatedBg);

      const container = document.getElementById("container");
      const interactKeyContent = document.getElementById("interact-key-content");

      if (event.data.value.state === "indicator") {
        container.classList.add("indicator-mode");
        let iconClass = event.data.value.icon || "fa-solid fa-hand-pointer";
        if (!iconClass.includes("fa-")) {
          iconClass = `fa-solid fa-${iconClass}`;
        }
        if (interactKeyContent) {
          interactKeyContent.innerHTML = `<i class="${iconClass}"></i>`;
        }
      } else {
        container.classList.remove("indicator-mode");
        if (interactKeyContent) {
          interactKeyContent.innerHTML = "<span>E</span>";
        }
      }

      if (event.data.value.options) {
        for (const type in event.data.value.options) {
          event.data.value.options[type].forEach((data, id) => {
            createOptions(type, data, id + 1);
          });
        }
        if (event.data.value.resetIndex) {
          setCurrentIndex(0);
        }

        updateHighlight();
      }
      break
    }

    case "interact": {
      onSelect();
      break
    }

    case "release": {
      resetHold();
      break
    }

    case "setColor": {
      const c = event.data.value
      const color = `rgb(${c[0]}, ${c[1]}, ${c[2]}, ${c[3] / 255})`
      setDefaultColor(color)
      body.style.setProperty('--theme-color', color)
      body.style.setProperty('--theme-color-rgb', `${c[0]}, ${c[1]}, ${c[2]}`)
      break
    }

    case "setCooldown": {
      body.style.opacity = event.data.value ? '0.3' : '1'
      const interactKeyContent = document.getElementById("interact-key-content");

      if (interactKeyContent) {
        interactKeyContent.innerHTML = event.data.value ? `<i class="fa-regular fa-hourglass-half"></i>` : '<span>E</span>';
      }

      break
    }
  }
});

window.addEventListener("load", async (event) => {
  await fetchNui("load");
});