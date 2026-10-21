import { fetchNui } from "./fetchNui.js";
const optionsWrapper = document.getElementById("options-wrapper");

let currentIndex = 0;
let isHolding = false;
let holdStartTime = null;
let holdTimeout = null;
let defaultColor = null;

export function setDefaultColor(color) {
  defaultColor = color;
  return defaultColor;
}

export function setCurrentIndex(newIndex) {
  currentIndex = newIndex;
  return currentIndex;
}

export function onSelect() {
  const options = optionsWrapper.querySelectorAll(".option-container");
  const option = options[currentIndex];

  if (!option) return;

  if (option.holdTime) {
    startHold(option);
  } else {
    fetchNui("select", [option.targetType, option.targetId]);
  }
}

function completeHold(option) {
  if (!isHolding) return;

  const options = optionsWrapper.querySelectorAll(".option-container");
  const currentOption = options[currentIndex];

  if (!currentOption) return;

  if (currentOption === option) {
    fetchNui("select", [option.targetType, option.targetId]);
  }
  resetHold();
}

export function resetHold() {
  isHolding = false;
  holdStartTime = null;
  clearTimeout(holdTimeout);
  
  const liquids = optionsWrapper.querySelectorAll(".progress-fill-liquid");
  liquids.forEach(liquid => {
    liquid.style.transition = "none";
    liquid.style.height = "0%";
  });

  const keyLiquid = document.getElementById("progress-fill-liquid");
  if (keyLiquid) {
    keyLiquid.style.transition = "none";
    keyLiquid.style.height = "0%";
  }
}

function startHold(option) {
  if (isHolding) return;

  isHolding = true;
  holdStartTime = Date.now();

  const activeOptionCard = optionsWrapper.querySelector(".option-container.highlighted");
  if (activeOptionCard) {
    const liquid = activeOptionCard.querySelector(".progress-fill-liquid");
    if (liquid) {
      liquid.style.transition = "none";
      liquid.style.height = "0%";
    }
  }

  const keyLiquid = document.getElementById("progress-fill-liquid");
  if (keyLiquid) {
    keyLiquid.style.transition = "none";
    keyLiquid.style.height = "0%";
  }

  setTimeout(() => {
    if (!isHolding) return;

    if (activeOptionCard) {
      const liquid = activeOptionCard.querySelector(".progress-fill-liquid");
      if (liquid) {
        liquid.style.transition = `height ${option.holdTime}ms linear`;
        liquid.style.height = "100%";
      }
    }

    if (keyLiquid) {
      keyLiquid.style.transition = `height ${option.holdTime}ms linear`;
      keyLiquid.style.height = "100%";
    }
  }, 20);

  holdTimeout = setTimeout(() => {
    completeHold(option);
  }, option.holdTime);
}

export function updateHighlight() {
  const options = optionsWrapper.querySelectorAll(".option-container");
  const animatedBg = document.querySelector('.animated-background');

  if (options.length > 0) {
    if (currentIndex < 0 || currentIndex >= options.length) {
      currentIndex = 0;
    }

    options.forEach(option => option.classList.remove("highlighted"));
    options[currentIndex].classList.add("highlighted");

    const selectedOption = options[currentIndex];
    const optionRect = selectedOption.getBoundingClientRect();
    const wrapperRect = optionsWrapper.getBoundingClientRect();

    if (animatedBg) {
        animatedBg.style.transform = `translateY(${optionRect.top - wrapperRect.top}px)`;
    }

    if (options[currentIndex].color) {
      const c = options[currentIndex].color;
      const color = `rgb(${c[0]}, ${c[1]}, ${c[2]}, ${c[3] / 255})`;
      document.body.style.setProperty('--theme-color', color);
      document.body.style.setProperty('--theme-color-rgb', `${c[0]}, ${c[1]}, ${c[2]}`);
    } else {
      document.body.style.setProperty('--theme-color', defaultColor);
      if (defaultColor) {
        const match = defaultColor.match(/\d+/g);
        if (match) {
          document.body.style.setProperty('--theme-color-rgb', `${match[0]}, ${match[1]}, ${match[2]}`);
        }
      }
    }
  }
}

window.addEventListener("wheel", (event) => {
  if (isHolding) return;

  const options = optionsWrapper.querySelectorAll(".option-container");
  if (options.length === 0) return;

  if (event.deltaY > 0) {
    currentIndex = setCurrentIndex((currentIndex + 1) % options.length);
  } else {
    currentIndex = setCurrentIndex((currentIndex - 1 + options.length) % options.length);
  }

  updateHighlight();

  fetchNui("currentOption", [currentIndex + 1]);
});

updateHighlight();
