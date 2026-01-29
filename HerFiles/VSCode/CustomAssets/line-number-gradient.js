(function () {
  const style = document.createElement('style');
  style.textContent = `
    .monaco-editor .margin-view-overlays .active-line-number {
      animation: slideIn 0.5s;
      animation-delay: 0.5s;
      animation-fill-mode: forwards;
    }

    @keyframes slideIn {
      0% {
        transform: translateX(0);
      }
      100% {
        transform: translateX(5px);
      }
    }
  `;
  document.head.appendChild(style);

  const updateLineNumbers = () => {
    const lineNumbers = document.querySelectorAll('.monaco-editor .margin-view-overlays .line-numbers');
    const activeLine = document.querySelector('.monaco-editor .margin-view-overlays .active-line-number');

    if (activeLine && lineNumbers.length) {
      const activeRect = activeLine.getBoundingClientRect();
      const activeCenterY = activeRect.top + activeRect.height / 2;
      const lineHeight = activeRect.height || 20;
      const fadeLines = 15;
      const maxDistance = lineHeight * fadeLines;

      lineNumbers.forEach(ln => {
        const rect = ln.getBoundingClientRect();
        const lineY = rect.top + rect.height / 2;
        const distance = Math.abs(lineY - activeCenterY);
        // NOTE(gabriela): a clamp here would make sense if it affected anything out of bounds, really
        const opacity = Math.max(0.15, 1 - (distance / maxDistance));
        ln.style.opacity = opacity;
      });
    }

    requestAnimationFrame(updateLineNumbers);
  };

  requestAnimationFrame(updateLineNumbers);
})();
