"""Run the offline BFRES skeleton inspector using the local .NET toolkit."""
import argparse
from pathlib import Path
import subprocess
import tempfile
from xml.sax.saxutils import escape


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('source', type=Path, help='Decoded .bfres (FRES magic)')
    parser.add_argument('output', type=Path)
    parser.add_argument('--library', type=Path, default=Path('artifacts/world_reference/toolkit/BfresLibrary/BfresLibrary/bin/Release/net8.0'))
    args = parser.parse_args()
    if args.output.exists():
        parser.error('Refusing existing output')
    if not (args.library / 'BfresLibrary.dll').is_file():
        parser.error('Build the local BfresLibrary net8 toolkit first')
    refs = list(args.library.resolve().glob('*.dll'))
    # Library annotation/JSON dependency. This is a local cached dependency,
    # not downloaded by the runtime inspector.
    cached = Path.home() / '.nuget/packages/newtonsoft.json/13.0.3/lib/net6.0/Newtonsoft.Json.dll'
    if not any(p.name == cached.name for p in refs) and cached.is_file():
        refs.append(cached)
    source = Path(__file__).with_name('BfresRigExport.cs').resolve()
    with tempfile.TemporaryDirectory(prefix='tidebreak-rig-reader-') as directory:
        project = Path(directory) / 'Reader.csproj'
        references = ''.join(f'<Reference Include="{escape(p.stem)}"><HintPath>{escape(str(p))}</HintPath></Reference>' for p in refs)
        project.write_text('<Project Sdk="Microsoft.NET.Sdk"><PropertyGroup><OutputType>Exe</OutputType><TargetFramework>net8.0</TargetFramework><NuGetAudit>false</NuGetAudit></PropertyGroup><ItemGroup>' + f'<Compile Include="{escape(str(source))}" Link="Program.cs"/>' + references + '</ItemGroup></Project>')
        for command in [
            ['dotnet', 'restore', str(project), '--ignore-failed-sources', '-v', 'quiet'],
            ['dotnet', 'run', '--project', str(project), '--no-restore', '--', str(args.source.resolve()), str(args.output.resolve())],
        ]:
            subprocess.run(command, check=True, timeout=180)


if __name__ == '__main__':
    main()
