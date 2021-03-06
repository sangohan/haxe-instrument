package instrument.profiler.reporter;

import haxe.Json;
import haxe.macro.Context;
import instrument.profiler.reporter.data.CPUProfile;
import instrument.profiler.summary.CallData;
import instrument.profiler.summary.CallSummaryData;
import instrument.profiler.summary.HierarchyCallData;

#if (sys || nodejs)
#end
// TODO fixme
class CPUProfileReporter extends FileBaseReporter implements IProfilerReporter {
	public function new(?fileName:Null<String>) {
		#if macro
		super(fileName, Context.definedValue("profiler-cpuprofile-reporter"), "profiler.cpuprofile");
		#else
		super(fileName, haxe.macro.Compiler.getDefine("profiler-cpuprofile-reporter"), "profiler.cpuprofile");
		#end
	}

	public function startProfiler() {}

	public function endProfiler(summary:Array<CallSummaryData>, root:HierarchyCallData) {
		var profile:Null<CPUProfile> = buildCPUProfile(root);
		if (profile != null) {
			outputProfile(profile.sure());
		}
	}

	function buildCPUProfile(tree:HierarchyCallData):Null<CPUProfile> {
		if (tree == null) {
			return null;
		}

		var name:String = tree.className;
		if ((tree.parent != null) && (tree.functionName != null) && (tree.functionName.length > 0)) {
			name += "." + tree.functionName;
		}
		var samples:Array<Int> = [];
		var timeDeltas:Array<Int> = [];
		if (tree.childs != null) {
			samples = tree.childs.map(c -> c.id);
			timeDeltas = tree.childs.map(c -> 0);
		}
		var profile:CPUProfile = {
			nodes: [],
			startTime: tree.lastStartTime * 1000,
			endTime: tree.lastEndTime * 1000,
			samples: samples,
			timeDeltas: timeDeltas
		}

		collectChildNodes(tree, profile);
		return profile;
	}

	function collectChildNodes(tree:HierarchyCallData, profile:CPUProfile) {
		if (tree == null) {
			return;
		}
		var index:Int = tree.location.lastIndexOf(":");
		var url:String = tree.location;
		var lineNum:Int = -1;
		if (index > 0) {
			url = tree.location.substr(0, index);
			lineNum = Std.parseInt(tree.sure().location.substr(index + 1)).sure();
		}
		var callFrame:CPUCallFrame = {
			functionName: tree.functionName,
			scriptId: tree.className,
			url: url,
			lineNumber: lineNum,
			columnNumber: 0
		}
		var ticks:Array<CPUPositionTickInfo> = [];
		if (lineNum > 0) {
			ticks = [
				{
					line: lineNum,
					ticks: Math.floor(tree.duration * 1000 * 1000)
				}
			];
		}
		var cpuNode:CPUProfileNode = {
			id: tree.id,
			callFrame: callFrame,
			hitCount: tree.count,
			children: [],
			positionTicks: ticks
		}
		if (tree.childs != null) {
			cpuNode.children = tree.childs.map(c -> c.id);
		}

		profile.nodes.push(cpuNode);
		if (tree.childs != null) {
			for (child in tree.childs.sure()) {
				collectChildNodes(child, profile);
			}
		}
	}

	public function enterFunction(data:CallData) {}

	public function exitFunction(data:CallData) {}

	function outputProfile(root:CPUProfile) {
		output(Json.stringify(root, "    "));
	}
}
