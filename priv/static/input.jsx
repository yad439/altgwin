'use strict';

class Input extends React.Component {
	constructor(props) {
		super(props);
		this.state = {
			value: ""
		}
	}

	handleChange(e) {
		this.setState({ value: e.target.value });
	}

	handleAddFile() {
		this.props.addFile(this.state.value);
		this.setState({ value: "" });
	}

	render() {
		return <div className="space-x-4">
			<input
				className="text-xl border-2 rounded px-2 shadow-md dark:shadow-slate-100/50 dark:bg-inherit border-inherit dark:text-white"
				id="input"
				type="text"
				value={this.state.value}
				onChange={this.handleChange.bind(this)}
			/>
			<button
				className="text-xl border-2 rounded px-6 shadow-md dark:shadow-slate-100/50 bg-slate-300 hover:bg-gray-300 dark:bg-slate-700 dark:hover:bg-gray-600 border-inherit dark:text-white"
				onClick={this.handleAddFile.bind(this)}
			>
				Add
			</button>
		</div>;
	}
}