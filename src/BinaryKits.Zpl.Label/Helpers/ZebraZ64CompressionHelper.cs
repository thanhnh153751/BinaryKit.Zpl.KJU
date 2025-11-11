using Ionic.Zlib;
using System;
using System.IO;
using System.Runtime.CompilerServices;
using System.Text.RegularExpressions;

[assembly: InternalsVisibleTo("BinaryKits.Zpl.Label.UnitTest")]

namespace BinaryKits.Zpl.Label.Helpers
{
    /// <summary>
    /// Z64 Data Compression Scheme for ~DG and ~DB Commands First compresses the data using the LZ77 algorithm to
    /// reduce its size, then compressed data is then encoded using Base64 A CRC is calculated across the Base64-encoded
    /// data. If the CRC-check fails or the download is aborted, the object can be invalidated by the printer. reduces
    /// the actual number of data bytes and the amount of time required to download graphic images and bitmapped fonts
    /// with the ~DG and ~DB commands
    /// </summary>
    public static class ZebraZ64CompressionHelper
    {
        private static Regex _z64Regex = new Regex(":(Z64):(\\S+):([0-9a-fA-F]+)", RegexOptions.Compiled);

        public static string Compress(string hexData)
        {
            var cleanedHexData = hexData.Replace("\n", string.Empty).Replace("\r", string.Empty);
            return Compress(cleanedHexData.ToBytesFromHex());
        }

        public static string Compress(byte[] bytes)
        {
#if NET5_0_OR_GREATER
            var data = DeflateCore(bytes);
#else
            var data = Deflate(bytes);
#endif
            var base64 = data.ToBase64();
            return ":Z64:" + base64 + ":" + Crc16.ComputeHex(base64.EncodeBytes());
        }

        public static byte[] Uncompress(string hexData)
        {
            var match = _z64Regex.Match(hexData);
            if (match.Success)
            {
                var imageBase64 = match.Groups[2].Value;
                var bytes = imageBase64.FromBase64();
#if NET5_0_OR_GREATER
                return InflateCore(bytes);
#else
                return Inflate(bytes);
#endif
            }
            else
            {
                throw new FormatException("Hex string not in Z64 format");
            }
        }

        /// <summary>
        /// Decompress graphics data with ZLib headers. .NET Standard has no ZlibStream implementation. Need to use
        /// DeflateStream and write header and checksum.
        /// </summary>
        /// <param name="data"></param>
        /// <returns></returns>
        internal static byte[] Inflate(byte[] data)
        {
            using (var outputStream = new MemoryStream())
            {
                using (var inputStream = new MemoryStream())
                {
                    //skip first 2 bytes of headers and last 4 bytes of checksum.
                    inputStream.Write(data, 2, data.Length - 6);
                    inputStream.Position = 0;
                    using (var decompressor = new DeflateStream(inputStream, CompressionMode.Decompress, true))
                    {
                        decompressor.CopyTo(outputStream);
                        return outputStream.ToArray();
                    }
                }
            }
        }

        /// <summary>
        /// Compress graphics data with ZLib headers  .NET Standard has no ZlibStream implementation.
        /// Need to use DeflateStream and write header and checksum. 
        /// Cleaned up implementation based on https://yal.cc/cs-deflatestream-zlib/
        /// </summary>
        /// <param name="data"></param>
        /// <param name="compressionLevel"></param>
        /// <returns></returns>
        internal static byte[] Deflate(byte[] data, CompressionLevel compressionLevel = CompressionLevel.Optimal)
        {
            // Ionic.Zlib handles the ZLib header (0x78, etc.) and the Adler-32 checksum automatically.
            // Therefore, the manual header writing and checksum calculation from the original code are removed.

            var ionicLevel = ConvertCompressionLevel(compressionLevel);

            using (var ms = new MemoryStream())
            {
                // ZlibStream creates the ZLib-wrapped compressed data (including header and checksum).
                // CompressionMode.Compress is the only mode needed here.
                using (var compressor = new ZlibStream(ms, CompressionMode.Compress, ionicLevel, true))
                {
                    compressor.Write(data, 0, data.Length);
                } // Closing the ZlibStream automatically flushes data and writes the Adler-32 checksum footer.

                ms.Seek(0, SeekOrigin.Begin);
                return ms.ToArray();
            }
        }


        private static Ionic.Zlib.CompressionLevel ConvertCompressionLevel(CompressionLevel level)
        {
            switch (level)
            {
                case CompressionLevel.NoCompression:
                    return Ionic.Zlib.CompressionLevel.None;
                case CompressionLevel.Fastest:
                    return Ionic.Zlib.CompressionLevel.BestSpeed;
                case CompressionLevel.Optimal:
                case CompressionLevel.SmallestSize:
                    // Note: We map Optimal and SmallestSize to the library's best option
                    // since the library's default is usually 'Optimal'.
                    return Ionic.Zlib.CompressionLevel.BestCompression;
                default:
                    return Ionic.Zlib.CompressionLevel.Default;
            }
        }
    }
    public enum CompressionLevel
    {
        // Corresponds to Ionic.Zlib.CompressionLevel.None
        NoCompression = 0,

        // Corresponds to Ionic.Zlib.CompressionLevel.BestSpeed
        Fastest = 1,

        // Corresponds to Ionic.Zlib.CompressionLevel.Default
        Optimal = 2,

        // Corresponds to Ionic.Zlib.CompressionLevel.BestCompression
        SmallestSize = 3
    }
}
