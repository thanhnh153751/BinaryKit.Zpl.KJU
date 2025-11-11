using System.Collections;
using System.Drawing;
using System.Drawing.Imaging;
using System.IO;
using System.Linq;
using System.Runtime.InteropServices.ComTypes;
using System.Text;

namespace BinaryKits.Zpl.Label.ImageConverters
{
    public class ImageSharpImageConverter : IImageConverter
    {
        /// <summary>
        /// Convert image to bitonal image (grf)
        /// </summary>
        /// <param name="imageData"></param>
        /// <returns></returns>
        public ImageResult ConvertImage(byte[] imageData)
        {
            // Use MemoryStream to load the image data into a Bitmap
            using (var ms = new MemoryStream(imageData))
            // Load the image using System.Drawing.Image.FromStream
            using (var originalImage = Image.FromStream(ms))
            using (var bitmapImage = new Bitmap(originalImage)) // Convert to Bitmap for pixel access
            using (var outputStream = new MemoryStream())
            {
                var width = bitmapImage.Width;
                var height = bitmapImage.Height;

                // Calculate bytesPerRow (same logic as SixLabors: pad to the next byte boundary)
                var bytesPerRow = width % 8 > 0
                    ? width / 8 + 1
                    : width / 8;

                var binaryByteCount = height * bytesPerRow;

                // Bitmap.GetPixel is very slow; for high performance, use Bitmap.LockBits,
                // but for a direct port of the SixLabors loop, GetPixel is the closest equivalent
                // if performance is not critical. We'll use GetPixel for simplicity here.

                int colorBits = 0;
                int j = 0;

                for (var y = 0; y < height; y++)
                {
                    for (var x = 0; x < width; x++)
                    {
                        // Get the pixel color
                        Color pixel = bitmapImage.GetPixel(x, y);

                        // Convert to grayscale value (average R, G, B) and check threshold
                        var isBlackPixel = ((pixel.R + pixel.G + pixel.B) / 3) < 128;

                        if (isBlackPixel)
                        {
                            // Set the corresponding bit (most significant bit first for the 7 - j logic)
                            colorBits |= 1 << (7 - j);
                        }

                        j++;

                        // Write the byte when 8 bits are collected, or at the end of the row (and pad)
                        if (j == 8 || x == (width - 1))
                        {
                            outputStream.WriteByte((byte)colorBits);
                            colorBits = 0;
                            j = 0;
                        }
                    }
                }

                return new ImageResult
                {
                    RawData = outputStream.ToArray(),
                    BinaryByteCount = binaryByteCount,
                    BytesPerRow = bytesPerRow
                };
            }
        }

        private byte Reverse(byte b)
        {
            var reverse = 0;
            for (var i = 0; i < 8; i++)
            {
                if ((b & (1 << i)) != 0)
                {
                    reverse |= 1 << (7 - i);
                }
            }
            return (byte)reverse;
        }

        /// <summary>
        /// Convert from bitonal image (grf) to png image
        /// </summary>
        /// <param name="imageData"></param>
        /// <param name="bytesPerRow"></param>
        /// <returns></returns>
        public byte[] ConvertImage(byte[] imageData, int bytesPerRow)
        {
            // Assuming 'Reverse' is defined elsewhere in your .NET 4.0 code:
            // imageData = imageData.Select(b => Reverse(b)).ToArray();

            var imageHeight = imageData.Length / bytesPerRow;
            var imageWidth = bytesPerRow * 8;

            // Create a new Bitmap with the calculated dimensions, using 32-bit ARGB format
            using (var image = new Bitmap(imageWidth, imageHeight, PixelFormat.Format32bppArgb))
            {
                // Convert the raw byte array into a BitArray (a .NET 4.0 supported class)
                // BitArray reads bits from least significant to most significant for each byte,
                // which may require careful consideration depending on your specific protocol.
                var bits = new BitArray(imageData);

                // System.Drawing does not directly expose a BitArray view like the original code's logic.
                // We will loop through the bits sequentially.
                for (var y = 0; y < imageHeight; y++)
                {
                    for (var x = 0; x < imageWidth; x++)
                    {
                        // Calculate the index in the 1D BitArray
                        var bitIndex = (y * imageWidth) + x;

                        if (bitIndex < bits.Length)
                        {
                            // Check if the bit is 'on' (representing a black pixel)
                            if (bits[bitIndex])
                            {
                                // Set the pixel to Black (0, 0, 0, 255)
                                image.SetPixel(x, y, Color.FromArgb(255, 0, 0, 0));
                            }
                            else
                            {
                                // Set the pixel to White (or another background color)
                                image.SetPixel(x, y, Color.FromArgb(255, 255, 255, 255));
                            }
                        }
                    }
                }

                using (var memoryStream = new MemoryStream())
                {
                    // Save the Bitmap as a PNG file into the memory stream
                    image.Save(memoryStream, ImageFormat.Png);
                    return memoryStream.ToArray();
                }
            }
        }
    }
}
