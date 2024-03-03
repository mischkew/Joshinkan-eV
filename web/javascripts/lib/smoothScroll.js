$(function() {
  $('a[data-scroll=true][href*=#]:not([href=#])').click(function(evt) {
    if (location.pathname.replace(/^\//,'') == this.pathname.replace(/^\//,'') && location.hostname == this.hostname) {
      var target = $(this.hash);
      var time = 2000;
      var customTime = $(evt.currentTarget).attr("data-scroll-time");

      if (customTime) {
        time = parseInt(customTime);
      }

      target = target.length ? target : $('[name=' + this.hash.slice(1) +']');
      if (target.length) {
        $('html,body').animate({
          scrollTop: target.offset().top
        }, time);

        // show hash in url without page jump
        history.pushState(null, null, this.hash);
        return false;
      }
    }
  });
});
