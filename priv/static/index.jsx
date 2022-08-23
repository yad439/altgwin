'use strict';

function download(files) {
	const query = files.map(f => "files[]=" + encodeURIComponent(f)).join('&');
	window.location.href = '/download?' + query;
}

class FileSelector extends React.Component {
	constructor(props) {
		super(props);
		this.state = {
			files: [],
		}
	}
	addFile(file) { this.setState((state, _) => { return { files: state.files.concat(file) } }); }
	removeFile(file) { this.setState((state, _) => { return { files: state.files.filter(f => f !== file) } }); }
	render() {
		return <div>
			<Input addFile={this.addFile.bind(this)} />
			<SelectedFileList files={this.state.files} removeFile={this.removeFile.bind(this)} />
			<button className="text-xl border-2 rounded px-6 shadow-md dark:shadow-slate-100/50 bg-slate-300 hover:bg-gray-300 dark:bg-slate-700 dark:hover:bg-gray-600 border-inherit dark:text-white" onClick={() => download(this.state.files)}>Download</button>
		</div>;
	}
}

const domContainer = document.querySelector('main');
const root = ReactDOM.createRoot(domContainer);
root.render(<FileSelector />);