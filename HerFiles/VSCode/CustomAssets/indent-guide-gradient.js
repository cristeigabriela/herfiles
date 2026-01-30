(function () {
  const style = document.createElement('style');
  style.textContent = `
    .monaco-editor .lines-content .core-guide-indent {
      will-change: opacity;
    }
  `;
  document.head.appendChild(style);

  const update = () => {
    const guides = document.querySelectorAll('.monaco-editor .lines-content .core-guide-indent');
    const activeLine = document.querySelector('.monaco-editor .margin-view-overlays .active-line-number');
    const activeRect = activeLine ? activeLine.getBoundingClientRect() : null;
    const activeY = activeRect ? activeRect.top + activeRect.height * 0.5 : -9999;

    const viewportCenter = window.innerHeight * 0.5;
    const maxDist = window.innerHeight * 0.5;

    for (let i = 0; i < guides.length; i++) {
      const r = guides[i].getBoundingClientRect();
      const guideY = r.top + r.height * 0.5;

      const dist = Math.abs(guideY - viewportCenter);
      guides[i].style.opacity = Math.max(0.1, 1 - dist / maxDist);
    }
  };

  const loop = () => {
    update();
    requestAnimationFrame(loop);
  };
  requestAnimationFrame(loop);
})();
