document.querySelectorAll('nav a').forEach(anchor => {
	anchor.addEventListener('click', function(e) {
		const href = this.getAttribute('href');

		if (href.startsWith('#')) {
			e.preventDefault();
			const target = document.querySelector(href);

			if (target) {
				window.scrollTo({
					top: target.offsetTop - 80,
					behavior: 'smooth'
				});
			}
		}
	});
});

const mobileMenuBtn = document.querySelector('.mobile-menu-btn');
const navMenu = document.querySelector('nav ul');

mobileMenuBtn.addEventListener('click', function() {
	navMenu.classList.toggle('show');
});

document.addEventListener('click', function(e) {
	if (!e.target.closest('nav') && !e.target.closest('.mobile-menu-btn')) {
		navMenu.classList.remove('show');
	}
});
