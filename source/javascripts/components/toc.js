function createTableOfContents(toc) {
  const headings = document.querySelectorAll('h2, h3, h4:not(.admonition--title), h5')

  let currentLevel = 1
  let currentList = toc

  headings.forEach((heading, index) => {
    const level = parseInt(heading.tagName.slice(1))
    const listItem = document.createElement('li')
    const link = document.createElement('a')
    link.classList.add('hyperlink')

    if (level > currentLevel) {
      while (level > currentLevel) {
        const nestedList = document.createElement('ul')
        const lastListItem = currentList.lastElementChild

        if (lastListItem) {
          lastListItem.appendChild(nestedList)
          currentList = nestedList
        }

        currentLevel++
      }
    } else if (level < currentLevel) {
      while (level < currentLevel) {
        currentList = currentList.parentElement.closest('ul')
        currentLevel--
      }
    }

    link.textContent = heading.innerText
    link.href = `#${heading.id}`
    listItem.appendChild(link)
    currentList.appendChild(listItem)
  })

}

up.compiler('.toc', createTableOfContents)

