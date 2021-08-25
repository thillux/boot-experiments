use digest::Digest;
use sha2::Sha256;
use sha3::Sha3_256;
use std::{fs, io};
use serde::{Serialize, Deserialize};
use serde_json::Result;
use std::fs::File;

// This example demonstrates clap's full 'custom derive' style of creating arguments which is the
// simplest method of use, but sacrifices some flexibility.
use clap::{AppSettings, Clap};

/// This doc string acts as a help message when the user runs '--help'
/// as do all doc strings on fields
#[derive(Clap)]
#[clap(version = "1.0", author = "Kevin K. <kbknapp@gmail.com>")]
#[clap(setting = AppSettings::ColoredHelp)]
struct Opts {
    /// Some input. Because this isn't an Option<T> it's required to be used
    input: String,
    output: String,
}

#[derive(Serialize, Deserialize, Debug)]
struct Output {
    sha256: String,
    sha3_256: String,
}

fn sha256_digest(path: &String) -> String {
    let mut file = fs::File::open(path).unwrap();
    let mut hasher = Sha256::new();
    io::copy(&mut file, &mut hasher).unwrap();
    let hash = hasher.finalize();
    return format!("{:x}", hash);
}

fn sha3_256_digest(path: &String) -> String {
    let mut file = fs::File::open(path).unwrap();
    let mut hasher = Sha3_256::new();
    io::copy(&mut file, &mut hasher).unwrap();
    let hash = hasher.finalize();
    return format!("{:x}", hash);
}

fn main() {
    let opts: Opts = Opts::parse();

    println!("Hash {}", opts.input);

    let out = Output{ sha256: sha256_digest(&opts.input), sha3_256: sha3_256_digest(&opts.input) };
    let serialized = serde_json::to_string(&out).unwrap();
    println!("{}", serialized);
    serde_json::to_writer_pretty(&File::create(opts.output).unwrap(), &out).unwrap();
}
