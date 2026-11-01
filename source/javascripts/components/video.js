up.compiler('.video-player', (player) => {
  let video = player.querySelector('.video-player--video')
  let playButton = player.querySelector('.video-player--play-button')

  video.preload = 'metadata'
  video.controls = false

  playButton.addEventListener('click', () => {
    video.play()
    video.controls = true
    playButton.remove()
    // The button had the focus. Without it, focus would fall back to the <body>, and a
    // screen reader would lose its place.
    video.focus()
  })
})
