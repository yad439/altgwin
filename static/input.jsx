'use strict';

function download() {
	const input = document.getElementById('input').value;
	const files = input.split(",");
	const query = files.map(f => "files[]=" + encodeURIComponent(f)).join('&');
	window.location.href = '/download?' + query;
}

function Input(props) {
	return <div className="space-x-4">
		<input
			className="text-xl border-2 rounded px-2 shadow-md dark:shadow-slate-100/50 dark:bg-inherit border-inherit dark:text-white"
			id="input"
			type="text"
		/>
		<button
			className="text-xl border-2 rounded px-6 shadow-md dark:shadow-slate-100/50 bg-slate-300 hover:bg-gray-300 dark:bg-slate-700 dark:hover:bg-gray-600 border-inherit dark:text-white"
			onClick={download}
		>
			Download
		</button>
	</div>;
}