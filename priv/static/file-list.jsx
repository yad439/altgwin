'use strict';

function FileEntry(props) {
	return <div className="flex justify-between text-lg rounded border dark:text-white dark:shadow-slate-100/50 p-0.5">
		<span className="mx-2">{props.name}</span>
		<button className="rounded bg-red-400 dark:bg-red-500 border shadow dark:shadow-red-400/75 dark:shadow-red-500/75 px-2" onClick={props.remove}>Remove</button>
	</div>;
}

function SelectedFileList(props) {
	return <div className="my-4 space-y-1.5">
		{props.files.map(f => <FileEntry key={f} name={f} remove={() => props.removeFile(f)} />)}
	</div>;
}