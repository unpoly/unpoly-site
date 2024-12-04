up.compiler('.video-player', (player) => {
  let video = player.querySelector('.video-player--video')
  let playButton = player.querySelector('.video-player--play-button')

  video.preload = 'metadata'
  video.controls = false

  playButton.addEventListener('click', () => {
    video.play()
    video.controls = true
    playButton.remove()
  })
})
