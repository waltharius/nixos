# Track-Package (Python Implementation)
# Same functionality as bash version but with better error handling
# and more maintainable code structure.
#
# Use this if you prefer Python's readability or need to extend
# functionality with complex logic (JSON export, filtering, etc.)
#
{pkgs, ...}:
pkgs.writers.writePython3Bin "track-package-py" {
  libraries = [];
  flakeIgnore = ["E501"]; # Allow long lines in comments
} ''
  import subprocess
  import sys
  import os
  from pathlib import Path


  def run_cmd(cmd, check=True):
      """Run command and return stdout, handling errors gracefully."""
      try:
          result = subprocess.run(
              cmd,
              capture_output=True,
              text=True,
              check=check
          )
          return result.stdout
      except subprocess.CalledProcessError:
          if not check:
              return ""
          print(f"Error running command: {' '.join(cmd)}", file=sys.stderr)
          return ""


  def get_generation_info(gen_link):
      """Extract generation metadata."""
      gen_num = gen_link.stem.split('-')[1]

      stat_result = run_cmd(["stat", "-c", "%y", str(gen_link)])
      gen_date = stat_result.split('.')[0] if stat_result else "unknown"

      git_rev_file = gen_link / "etc" / "nixos-git-revision"
      git_rev = ""
      if git_rev_file.exists():
          try:
              git_rev = git_rev_file.read_text().strip()
          except IOError:
              pass

      return gen_num, gen_date, git_rev


  def find_program_in_generation(gen_link, program):
      """Find program in generation using fast and slow path."""
      bin_path = gen_link / "sw" / "bin" / program
      if bin_path.exists() and os.access(bin_path, os.X_OK):
          try:
              return Path(os.readlink(bin_path)).resolve()
          except OSError:
              pass

      closure = run_cmd(
          ["nix-store", "-qR", str(gen_link)],
          check=False
      )

      for line in closure.splitlines():
          if f"/{program}-" in line and any(c.isdigit() for c in line):
              return Path(line)

      return None


  def extract_version(path, program):
      """Extract version from store path."""
      name = path.name
      return name.replace(f"{program}-", "", 1)


  def main():
      """Main entry point."""
      if len(sys.argv) < 2:
          print("Usage: track-package-py <program-name>")
          print("Example: track-package-py firefox")
          sys.exit(1)

      program = sys.argv[1]
      print(f"Tracking '{program}' across all generations...")
      print()

      profile_dir = Path("/nix/var/nix/profiles")
      try:
          generations = sorted(
              profile_dir.glob("system-*-link"),
              key=lambda p: int(p.stem.split('-')[1])
          )
      except (ValueError, IndexError) as e:
          print(f"Error reading generations: {e}", file=sys.stderr)
          sys.exit(1)

      prev_version = None
      found_count = 0

      for gen_link in generations:
          if not gen_link.is_symlink():
              continue

          gen_num, gen_date, git_rev = get_generation_info(gen_link)
          program_path = find_program_in_generation(gen_link, program)

          if program_path:
              version = extract_version(program_path, program)

              if version != prev_version:
                  if prev_version is not None:
                      print("=" * 60)

                  print(f"Generation:     #{gen_num}")
                  print(f"Date:           {gen_date}")

                  if prev_version:
                      print(f"Version change: {prev_version} -> {version}")
                  else:
                      print(f"Version:        {version}")

                  if git_rev:
                      print(f"Git commit:     {git_rev[:12]}")

                  print(f"Store path:     {program_path}")
                  print()

                  prev_version = version
                  found_count += 1

      if found_count == 0:
          print(f"[X] Package '{program}' not found in any generation")
          sys.exit(1)
      else:
          total_gens = len(generations)
          print(f"[OK] Found {program} in {total_gens} total generations")


  if __name__ == "__main__":
      main()
''
