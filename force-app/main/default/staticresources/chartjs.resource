/* Minimal Chart.js stub for validation. Replace with real Chart.js for production charts. */
(function(){
  if (typeof window !== 'undefined' && !window.Chart) {
    window.Chart = function(ctx, config){
      return {
        destroy: function(){},
        update: function(){},
        config: config || {},
      };
    };
  }
})();
