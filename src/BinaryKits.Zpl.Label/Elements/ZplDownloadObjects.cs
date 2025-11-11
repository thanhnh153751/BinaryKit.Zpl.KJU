using BinaryKits.Zpl.Label.Helpers;
using System;
using System.Collections.Generic;
using System.Drawing;
using System.Drawing.Imaging;
using System.IO;
using System.Text;

namespace BinaryKits.Zpl.Label.Elements
{
    /// <summary>
    /// Download Graphics / Native TrueType or OpenType Font
    /// The ~DY command downloads to the printer graphic objects or fonts in any supported format.
    /// This command can be used in place of ~DG for more saving and loading options.
    /// ~DY is the preferred command to download TrueType fonts on printers with firmware greater than X.13.
    /// It is faster than ~DU.
    /// </summary>
    /// <remarks>
    /// Format:~DYd:f,b,x,t,w,data
    /// d = file location
    /// f = file name
    /// b = format downloaded in data field
    /// x = extension of stored file
    /// t = total number of bytes in file
    /// w = total number of bytes per row
    /// data = data
    /// </remarks>
    public class ZplDownloadObjects : ZplDownload
    {
        public string ObjectName { get; private set; }
        public byte[] ImageData { get; private set; }

        public ZplDownloadObjects(char storageDevice, string imageName, byte[] imageData)
            : base(storageDevice)
        {
            ObjectName = imageName;
            ImageData = imageData;
        }

        ///<inheritdoc/>
        public override IEnumerable<string> Render(ZplRenderOptions context)
        {
            byte[] objectData;
            using (var ms = new MemoryStream(ImageData))
            using (var originalImage = System.Drawing.Image.FromStream(ms))
            using (var image = new Bitmap(originalImage))
            {
                if (context.ScaleFactor != 1)
                {
                    var scaleWidth = (int)Math.Round(image.Width * context.ScaleFactor);
                    var scaleHeight = (int)Math.Round(image.Height * context.ScaleFactor);

                    using (var scaledImage = image.GetThumbnailImage(scaleWidth, scaleHeight, null, IntPtr.Zero))
                    {
                        // To replace the original image variable, we must save the scaled image
                        // and then reload it or save it directly to the output stream.
                        // We'll save the scaled image to memory stream for conversion.

                        using (var outputStream = new MemoryStream())
                        {
                            // 2. Image Saving (PNG format)
                            // The #if NET6_0_OR_GREATER block for PNG metadata is not needed
                            // as System.Drawing manages this differently/doesn't have the same issue.
                            scaledImage.Save(outputStream, ImageFormat.Png);
                            objectData = outputStream.ToArray();
                        }
                    }
                }
                else
                {
                    // If no scaling, just save the original image data as PNG
                    using (var outputStream = new MemoryStream())
                    {
                        image.Save(outputStream, ImageFormat.Png);
                        objectData = outputStream.ToArray();
                    }
                }

            }

            var hexString = ByteHelper.BytesToHex(objectData);

            var formatDownloadedInDataField = 'P'; //portable network graphic (.PNG) - ZB64 encoded 
            var extensionOfStoredFile = 'P'; //store as compressed (.PNG)

            var result = new List<string>
            {
                $"~DY{StorageDevice}:{ObjectName},{formatDownloadedInDataField},{extensionOfStoredFile},{objectData.Length},,{hexString}"
            };

            return result;
        }
    }
}
